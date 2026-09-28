-- Profiles and friends API. Everything is computed here, as the caller
-- (auth.uid()), so privacy never depends on the frontend. Errors are raised as
-- 'yg:<code>:<message>' so the app can show them as they are.

-- my_profile() must not be callable without a session (functions are granted to PUBLIC by default).
revoke execute on function my_profile() from public;
grant execute on function my_profile() to authenticated;

create or replace function yg_me() returns uuid
language plpgsql stable as $$
begin
  if auth.uid() is null then
    raise exception 'yg:unauthorized:Tu sesión ha caducado. Vuelve a entrar.';
  end if;
  return auth.uid();
end;
$$;

create or replace function friendship_status(viewer uuid, other uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when viewer = other then 'self'
    when are_friends(viewer, other) then 'friends'
    when exists (select 1 from friend_requests where from_id = viewer and to_id = other and status = 'pending') then 'request_sent'
    when exists (select 1 from friend_requests where from_id = other and to_id = viewer and status = 'pending') then 'request_received'
    else 'none'
  end;
$$;

-- A person as shown in lists: name, avatar, town (if allowed) and the relationship.
create or replace function person_json(viewer uuid, target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'first_name', p.first_name,
    'last_name', p.last_name,
    'avatar_url', p.avatar_url,
    'city', case when can_view_city(viewer, p.id) then p.city else '' end,
    'friendship', friendship_status(viewer, p.id),
    'mutual_friends', mutual_friends(viewer, p.id),
    'can_send_request', friendship_status(viewer, p.id) = 'none' and can_send_request(viewer, p.id)
  )
  from profiles p where p.id = target;
$$;

create or replace function people_view(ids uuid[]) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(person_json(yg_me(), id) order by ord), '[]'::jsonb)
  from unnest(ids) with ordinality as t(id, ord)
  where exists (select 1 from profiles where profiles.id = t.id);
$$;

-- Everything the profile page needs, respecting "Quién puede ver mi perfil".
create or replace function profile_view(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p profiles;
  visible boolean;
begin
  select * into p from profiles where id = target;
  if not found then
    raise exception 'yg:not_found:Esta persona no existe o ha eliminado su cuenta.';
  end if;
  visible := can_view_profile(me, target);
  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', p.id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'avatar_url', p.avatar_url,
      'cover_url', case when visible then p.cover_url end,
      'city', case when can_view_city(me, target) then p.city else '' end,
      -- Coordinates only ever go to their owner.
      'city_lat', case when me = target then p.city_lat end,
      'city_lng', case when me = target then p.city_lng end,
      'bio', case when visible then p.bio else '' end,
      'birthday', case when visible then p.birthday end,
      'studies', case when visible then p.studies else '' end,
      'work', case when visible then p.work else '' end,
      'visit_count', p.visit_count,
      'created_at', p.created_at
    ),
    'friendship', friendship_status(me, target),
    'friends_count', (select count(*) from friendships where target in (user_a, user_b)),
    'mutual_friends', mutual_friends(me, target),
    'posts_count', case when visible then (select count(*) from posts where author_id = target) else 0 end,
    'photos_count', case when visible then (select count(*) from photos where owner_id = target) else 0 end,
    'can_view_profile', visible,
    'can_send_request', friendship_status(me, target) = 'none' and can_send_request(me, target),
    'visits', p.visit_count
  );
end;
$$;

-- Accent- and case-insensitive text for search ("Lucía" matches "lucia").
create or replace function yg_fold(value text) returns text
language sql immutable as $$
  select translate(lower(coalesce(value, '')), 'áàäâéèëêíìïîóòöôúùüûñç', 'aaaaeeeeiiiioooouuuunc');
$$;

create or replace function search_people(q text, max_results int default 30) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id),
  found as (
    select p.id, mutual_friends(me.id, p.id) as mutual
    from profiles p, me
    where p.id <> me.id
      and length(trim(q)) > 0
      and yg_fold(p.first_name || ' ' || p.last_name || ' ' || case when can_view_city(me.id, p.id) then p.city else '' end)
          like '%' || yg_fold(trim(q)) || '%'
    order by mutual desc, p.first_name
    limit least(max_results, 50)
  )
  select people_view(coalesce(array_agg(id), '{}')) from found;
$$;

-- People you may know: friends of friends you can send a request to.
create or replace function friend_suggestions(max_results int default 5) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id),
  found as (
    select p.id, mutual_friends(me.id, p.id) as mutual
    from profiles p, me
    where p.id <> me.id
      and friendship_status(me.id, p.id) = 'none'
      and mutual_friends(me.id, p.id) > 0
      and can_send_request(me.id, p.id)
    order by mutual desc
    limit least(max_results, 20)
  )
  select people_view(coalesce(array_agg(id), '{}')) from found;
$$;

create or replace function list_friends(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not can_view_profile(me, target) then
    raise exception 'yg:forbidden:Este perfil es privado.';
  end if;
  return people_view(coalesce((
    select array_agg(f.id order by p.first_name)
    from (select case when user_a = target then user_b else user_a end as id from friendships where target in (user_a, user_b)) f
    join profiles p on p.id = f.id
  ), '{}'));
end;
$$;

create or replace function list_friend_requests() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select jsonb_build_object(
    'incoming', coalesce((
      select jsonb_agg(jsonb_build_object('id', r.id, 'person', person_json(me.id, r.from_id), 'created_at', r.created_at) order by r.created_at desc)
      from friend_requests r where r.to_id = me.id and r.status = 'pending'
    ), '[]'::jsonb),
    'outgoing', coalesce((
      select jsonb_agg(jsonb_build_object('id', r.id, 'person', person_json(me.id, r.to_id), 'created_at', r.created_at) order by r.created_at desc)
      from friend_requests r where r.from_id = me.id and r.status = 'pending'
    ), '[]'::jsonb)
  )
  from me;
$$;

-- ---- Friendship actions: each returns the person with the new status --------

create or replace function send_friend_request(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not exists (select 1 from profiles where id = target) then
    raise exception 'yg:not_found:Esta persona no existe o ha eliminado su cuenta.';
  end if;
  -- If they had already asked us, sending a request means accepting it.
  if friendship_status(me, target) = 'request_received' then
    perform accept_friend_request(target);
    return person_json(me, target);
  end if;
  if friendship_status(me, target) = 'request_sent' then
    raise exception 'yg:conflict:Ya le has enviado una solicitud de amistad.';
  end if;
  if friendship_status(me, target) = 'friends' then
    raise exception 'yg:conflict:Ya sois amigos.';
  end if;
  if friendship_status(me, target) <> 'none' or not can_send_request(me, target) then
    raise exception 'yg:forbidden:Esta persona no acepta solicitudes de amistad ahora mismo.';
  end if;
  insert into friend_requests (from_id, to_id) values (me, target);
  return person_json(me, target);
end;
$$;

create or replace function cancel_friend_request(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  update friend_requests set status = 'cancelled', responded_at = now()
  where from_id = me and to_id = target and status = 'pending';
  if not found then raise exception 'yg:not_found:La solicitud ya no existe.'; end if;
  return person_json(me, target);
end;
$$;

create or replace function answer_friend_request(sender uuid, accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if friendship_status(me, sender) <> 'request_received' then
    raise exception 'yg:not_found:La solicitud ya no existe.';
  end if;
  if accept then
    perform accept_friend_request(sender);
  else
    update friend_requests set status = 'rejected', responded_at = now()
    where from_id = sender and to_id = me and status = 'pending';
  end if;
  return person_json(me, sender);
end;
$$;

create or replace function remove_friend(other uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  delete from friendships where user_a = least(me, other) and user_b = greatest(me, other);
  if not found then raise exception 'yg:not_found:No sois amigos.'; end if;
  return person_json(me, other);
end;
$$;

-- Only signed-in users call the API.
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'people_view(uuid[])', 'profile_view(uuid)', 'search_people(text, int)', 'friend_suggestions(int)',
    'list_friends(uuid)', 'list_friend_requests()', 'send_friend_request(uuid)', 'cancel_friend_request(uuid)',
    'answer_friend_request(uuid, boolean)', 'remove_friend(uuid)', 'register_visit(uuid)'
  ] loop
    execute format('revoke execute on function %s from public', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;

-- ---- Avatars and covers: public bucket, each user writes in their own folder ----

insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict do nothing;

create policy "upload own avatar and cover" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "replace own avatar and cover" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete own avatar and cover" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
