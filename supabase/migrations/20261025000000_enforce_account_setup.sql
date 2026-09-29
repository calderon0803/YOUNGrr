-- Accounts with something pending (age not confirmed, temporary password or
-- profile created by hand) cannot use the API until they complete it: the app
-- already sends them to the setup page, and now the database enforces it for
-- direct calls too. Only the functions needed to complete the setup, download
-- the data or delete the account keep working meanwhile.
--
-- Every RPC gets the caller through yg_me(), so the check lives there.

create or replace function yg_me_setup() returns uuid
language plpgsql stable set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'yg:unauthorized:Tu sesión ha caducado. Vuelve a entrar.';
  end if;
  return auth.uid();
end;
$$;

create or replace function yg_me() returns uuid
language plpgsql stable set search_path = public as $$
declare
  me uuid := yg_me_setup();
  pending boolean;
begin
  select p.must_change_password or p.needs_setup or p.adult_confirmed_at is null into pending
  from profiles p where p.id = me;
  if pending then
    raise exception 'yg:setup_required:Completa tu cuenta antes de seguir.';
  end if;
  return me;
end;
$$;

create or replace function confirm_adult(birth_date date) returns profiles
language plpgsql security definer set search_path = public as $$
declare
  result profiles;
begin
  if not yg_is_adult(birth_date) then
    raise exception 'yg:forbidden:YOUNGrr es solo para mayores de 18 años.';
  end if;
  update profiles set adult_confirmed_at = coalesce(adult_confirmed_at, now()) where id = yg_me_setup() returning * into result;
  return result;
end;
$$;

create or replace function complete_profile_setup(first_name text, last_name text, city text, city_lat double precision, city_lng double precision)
returns profiles
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me_setup();
  result profiles;
begin
  first_name := trim(coalesce(first_name, ''));
  last_name := trim(coalesce(last_name, ''));
  city := trim(coalesce(city, ''));
  if char_length(first_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu nombre (máximo 40 caracteres).'; end if;
  if char_length(last_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu apellido (máximo 40 caracteres).'; end if;
  if city <> '' and (char_length(city) > 60 or city_lat is null or city_lng is null) then
    raise exception 'yg:validation:Elige tu ciudad o pueblo de la lista.';
  end if;
  update profiles p set
    first_name = complete_profile_setup.first_name,
    last_name = complete_profile_setup.last_name,
    city = complete_profile_setup.city,
    city_lat = case when complete_profile_setup.city = '' then null else complete_profile_setup.city_lat end,
    city_lng = case when complete_profile_setup.city = '' then null else complete_profile_setup.city_lng end,
    needs_setup = false
  where p.id = me
  returning * into result;
  return result;
end;
$$;

create or replace function delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me_setup();
  remaining int;
begin
  select count(*) into remaining from storage.objects
  where bucket_id in ('photos', 'avatars', 'covers') and (storage.foldername(name))[1] = me::text;
  if remaining > 0 then
    raise exception 'yg:conflict:Todavía quedan archivos tuyos. Vuelve a intentarlo.';
  end if;

  perform yg_account_deletion_holds(me);

  -- Conversations lose their meaning without one of the two people: they go
  -- for both (the other person's messages in them too).
  delete from conversations c
  where exists (select 1 from conversation_members m where m.conversation_id = c.id and m.user_id = me);
  -- Invitations that brought this person in hold their email.
  delete from invitations where used_by = me;
  delete from notifications where actor_id = me or user_id = me;

  delete from auth.users where id = me;
end;
$$;

create or replace function export_my_data() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me_setup() as id)
  select jsonb_build_object(
    'generated_at', now(),
    'account', (
      select jsonb_build_object('email', u.email, 'created_at', u.created_at, 'last_sign_in_at', u.last_sign_in_at)
      from auth.users u, me where u.id = me.id
    ),
    'profile', (
      select jsonb_build_object(
        'first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url, 'cover_path', p.cover_path,
        'city', p.city, 'city_lat', p.city_lat, 'city_lng', p.city_lng, 'bio', p.bio, 'birthday', p.birthday,
        'studies', p.studies, 'work', p.work, 'visit_count', p.visit_count, 'created_at', p.created_at,
        'adult_confirmed_at', p.adult_confirmed_at
      ) from profiles p, me where p.id = me.id
    ),
    'settings', (select to_jsonb(s) - 'user_id' from user_settings s, me where s.user_id = me.id),
    'status', (select jsonb_build_object('text', po.text, 'created_at', po.created_at) from posts po, me where po.author_id = me.id and po.kind = 'status'),
    'albums', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'description', a.description, 'kind', a.kind, 'created_at', a.created_at) order by a.created_at)
      from albums a, me where a.owner_id = me.id), '[]'::jsonb),
    'photos', coalesce((select jsonb_agg(jsonb_build_object('id', ph.id, 'album_id', ph.album_id, 'storage_path', ph.storage_path, 'caption', ph.caption, 'width', ph.width, 'height', ph.height, 'created_at', ph.created_at) order by ph.created_at)
      from photos ph, me where ph.owner_id = me.id), '[]'::jsonb),
    'photos_shared_with_me', coalesce((select jsonb_agg(jsonb_build_object('photo_id', o.photo_id, 'status', o.status, 'created_at', o.created_at))
      from photo_owners o, me where o.user_id = me.id), '[]'::jsonb),
    'tags_of_me', coalesce((select jsonb_agg(jsonb_build_object('photo_id', t.photo_id, 'created_at', t.created_at))
      from photo_tags t, me where t.user_id = me.id), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object('text', c.text, 'on', case when c.post_id is not null then 'status' else 'photo' end, 'created_at', c.created_at) order by c.created_at)
      from comments c, me where c.author_id = me.id), '[]'::jsonb),
    'grrs', coalesce((select jsonb_agg(jsonb_build_object('on', case when g.post_id is not null then 'status' else 'photo' end, 'created_at', g.created_at) order by g.created_at)
      from grrs g, me where g.user_id = me.id), '[]'::jsonb),
    'wall_messages_written', coalesce((select jsonb_agg(jsonb_build_object('text', w.text, 'on_profile_of', p.first_name || ' ' || p.last_name, 'created_at', w.created_at) order by w.created_at)
      from wall_messages w join profiles p on p.id = w.profile_id, me where w.author_id = me.id), '[]'::jsonb),
    'wall_messages_received', (select count(*) from wall_messages w, me where w.profile_id = me.id and w.author_id <> me.id),
    'friends', coalesce((select jsonb_agg(jsonb_build_object('name', p.first_name || ' ' || p.last_name, 'since', f.created_at) order by f.created_at)
      from friendships f join profiles p on p.id = case when f.user_a = (select id from me) then f.user_b else f.user_a end, me
      where me.id in (f.user_a, f.user_b)), '[]'::jsonb),
    'friend_requests_sent', coalesce((select jsonb_agg(jsonb_build_object('status', r.status, 'created_at', r.created_at))
      from friend_requests r, me where r.from_id = me.id), '[]'::jsonb),
    'events_created', coalesce((select jsonb_agg(jsonb_build_object('title', e.title, 'description', e.description, 'date', e.date, 'time', e.time, 'location', e.location, 'created_at', e.created_at))
      from events e, me where e.creator_id = me.id), '[]'::jsonb),
    'events_answered', coalesce((select jsonb_agg(jsonb_build_object('event_id', m.event_id, 'status', m.status, 'responded_at', m.responded_at))
      from event_members m, me where m.user_id = me.id), '[]'::jsonb),
    'messages_sent', coalesce((select jsonb_agg(jsonb_build_object(
        'to', (select p.first_name || ' ' || p.last_name from conversation_members cm join profiles p on p.id = cm.user_id
               where cm.conversation_id = m.conversation_id and cm.user_id <> me.id limit 1),
        'text', m.text, 'deleted', m.deleted_at is not null, 'created_at', m.created_at) order by m.created_at)
      from messages m, me where m.sender_id = me.id), '[]'::jsonb),
    'messages_received_count', (select count(*) from messages m join conversation_members cm on cm.conversation_id = m.conversation_id, me
      where cm.user_id = me.id and m.sender_id <> me.id),
    'invitations_sent', coalesce((select jsonb_agg(jsonb_build_object('email', i.email, 'created_at', i.created_at, 'expires_at', i.expires_at, 'used', i.used_by is not null))
      from invitations i, me where i.inviter_id = me.id), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('about', r.target_type, 'reason', r.reason, 'status', r.status, 'created_at', r.created_at))
      from reports r, me where r.reporter_id = me.id), '[]'::jsonb)
  );
$$;
