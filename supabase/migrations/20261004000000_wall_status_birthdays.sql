-- Tuenti-style profile: wall ("tablón"), current status and friends' birthdays.

alter type notification_type add value if not exists 'wall_message';

-- ---- Wall ----------------------------------------------------------------------
-- Whoever can see the profile reads it; the owner and their friends write on it;
-- the author or the profile owner delete a message.

create table wall_messages (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  author_id  uuid not null references profiles (id) on delete cascade,
  text       text not null check (char_length(text) between 1 and 500),
  created_at timestamptz not null default now()
);
create index wall_messages_profile_created on wall_messages (profile_id, created_at desc);

alter table wall_messages enable row level security;

create policy "wall readable with the profile" on wall_messages for select to authenticated
  using (can_view_profile(auth.uid(), profile_id));
create policy "owner and friends write" on wall_messages for insert to authenticated
  with check (author_id = auth.uid() and (profile_id = auth.uid() or are_friends(auth.uid(), profile_id)));
create policy "author or owner delete" on wall_messages for delete to authenticated
  using (auth.uid() in (author_id, profile_id));

create or replace function list_wall(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not can_view_profile(me, target) then
    raise exception 'yg:forbidden:Este perfil es privado.';
  end if;
  return jsonb_build_object(
    'can_write', me = target or are_friends(me, target),
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', w.id, 'profile_id', w.profile_id, 'author_id', w.author_id, 'text', w.text, 'created_at', w.created_at,
        'author', jsonb_build_object('id', a.id, 'first_name', a.first_name, 'last_name', a.last_name, 'avatar_url', a.avatar_url)
      ) order by w.created_at desc)
      from wall_messages w join profiles a on a.id = w.author_id
      where w.profile_id = target
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function add_wall_message(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  if not exists (select 1 from profiles where id = target) then
    raise exception 'yg:not_found:Esta persona no existe o ha eliminado su cuenta.';
  end if;
  if me <> target and not are_friends(me, target) then
    raise exception 'yg:forbidden:Solo sus amigos pueden escribir en su tablón.';
  end if;
  body := trim(coalesce(body, ''));
  if body = '' then raise exception 'yg:validation:El mensaje es obligatorio.'; end if;
  if char_length(body) > 500 then raise exception 'yg:validation:El mensaje no puede superar los 500 caracteres.'; end if;
  insert into wall_messages (profile_id, author_id, text) values (target, me, body) returning id into new_id;
  perform push_notification(target, me, 'wall_message', target);
  return (
    select jsonb_build_object(
      'id', w.id, 'profile_id', w.profile_id, 'author_id', w.author_id, 'text', w.text, 'created_at', w.created_at,
      'author', jsonb_build_object('id', a.id, 'first_name', a.first_name, 'last_name', a.last_name, 'avatar_url', a.avatar_url)
    )
    from wall_messages w join profiles a on a.id = w.author_id where w.id = new_id
  );
end;
$$;

create or replace function delete_wall_message(target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  w wall_messages;
begin
  select * into w from wall_messages where id = target;
  if w.id is null then raise exception 'yg:not_found:Este mensaje ya no existe.'; end if;
  if me not in (w.author_id, w.profile_id) then raise exception 'yg:forbidden:No puedes borrar este mensaje.'; end if;
  delete from wall_messages where id = target;
  if not exists (select 1 from wall_messages where profile_id = w.profile_id and author_id = w.author_id) then
    delete from notifications where type = 'wall_message' and user_id = w.profile_id and actor_id = w.author_id;
  end if;
end;
$$;

-- ---- Friends' birthdays (only friends: they can always see your profile) --------

create or replace function upcoming_birthdays(days int default 30) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id),
  friends as (
    select case when f.user_a = me.id then f.user_b else f.user_a end as id
    from friendships f, me where me.id in (f.user_a, f.user_b)
  ),
  next_dates as (
    select p.id, p.first_name, p.last_name, p.avatar_url,
      case when x.d >= current_date then x.d else (x.d + interval '1 year')::date end as next_date
    from profiles p
    join friends f on f.id = p.id
    cross join lateral (
      select make_date(extract(year from current_date)::int, extract(month from p.birthday)::int, extract(day from p.birthday)::int) as d
    ) x
    where p.birthday is not null
      -- 29 February only exists in leap years.
      and not (extract(month from p.birthday) = 2 and extract(day from p.birthday) = 29)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'person', jsonb_build_object('id', id, 'first_name', first_name, 'last_name', last_name, 'avatar_url', avatar_url),
    'date', next_date,
    'days_left', next_date - current_date
  ) order by next_date), '[]'::jsonb)
  from next_dates
  where next_date - current_date <= least(days, 60);
$$;

-- ---- Profile page with the current status ---------------------------------------
-- The status is the latest text-only post ("¿Qué estás haciendo?").

create or replace function profile_view(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p profiles;
  visible boolean;
  latest posts;
begin
  select * into p from profiles where id = target;
  if not found then
    raise exception 'yg:not_found:Esta persona no existe o ha eliminado su cuenta.';
  end if;
  visible := can_view_profile(me, target);
  if visible then
    select * into latest from posts
    where author_id = target and photo_id is null and trim(text) <> ''
    order by created_at desc limit 1;
  end if;
  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', p.id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'avatar_url', p.avatar_url,
      'city', case when can_view_city(me, target) then p.city else '' end,
      -- Coordinates and the visit counter only ever go to their owner.
      'city_lat', case when me = target then p.city_lat end,
      'city_lng', case when me = target then p.city_lng end,
      'visit_count', case when me = target then p.visit_count end,
      'bio', case when visible then p.bio else '' end,
      'birthday', case when visible then p.birthday end,
      'studies', case when visible then p.studies else '' end,
      'work', case when visible then p.work else '' end,
      'created_at', p.created_at
    ),
    'friendship', friendship_status(me, target),
    'friends_count', (select count(*) from friendships where target in (user_a, user_b)),
    'mutual_friends', mutual_friends(me, target),
    'posts_count', case when visible then (select count(*) from posts where author_id = target) else 0 end,
    'photos_count', case when visible then (select count(*) from photos where owner_id = target) else 0 end,
    'can_view_profile', visible,
    'can_send_request', friendship_status(me, target) = 'none' and can_send_request(me, target),
    'visits', case when me = target then p.visit_count end,
    'status', case when latest.id is null then null else jsonb_build_object('post_id', latest.id, 'text', latest.text, 'created_at', latest.created_at) end
  );
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array['list_wall(uuid)', 'add_wall_message(uuid, text)', 'delete_wall_message(uuid)', 'upcoming_birthdays(int)'] loop
    execute format('revoke execute on function %s from public', fn);
    execute format('revoke execute on function %s from anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;
