-- Audit R02, R04, R05, P3: the profile is edited through RPCs that only touch
-- the editable fields; buckets only accept JPEG images of a bounded size; the
-- cover moves to a private bucket that follows profile privacy; others see the
-- birthday without the year.

-- ---- Storage: bounded JPEG images only ----------------------------------------------
-- The app always re-encodes pictures to JPEG in the browser; the limits are
-- enforced by Storage for direct API calls too.

update storage.buckets set file_size_limit = 8388608, allowed_mime_types = array['image/jpeg'] where id = 'photos';
update storage.buckets set file_size_limit = 2097152, allowed_mime_types = array['image/jpeg'] where id = 'avatars';

-- The cover is now a path in the private bucket. Old covers were public URLs in
-- "avatars" (the app has no cover UI): they are dropped; the files are listed
-- by admin_storage_orphans() for deletion.
alter table profiles add column cover_path text check (cover_path is null or split_part(cover_path, '/', 1) = id::text);
alter table profiles drop column cover_url;

-- Deleting a file needs SELECT on it too: owners can see their own avatars
-- (public files are served without this; it only lets the owner remove them).
create policy "read own avatars" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Covers are private: readable by the owner and by whoever can see the profile.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('covers', 'covers', false, 5242880, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "upload own cover" on storage.objects for insert to authenticated
  with check (bucket_id = 'covers' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete own cover" on storage.objects for delete to authenticated
  using (bucket_id = 'covers' and (storage.foldername(name))[1] = auth.uid()::text);
create or replace function yg_can_read_cover_file(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select split_part(path, '/', 1) = auth.uid()::text
    or exists (select 1 from profiles p where p.cover_path = path and can_view_profile(auth.uid(), p.id));
$$;
grant execute on function yg_can_read_cover_file(text) to authenticated;

create policy "read covers you can see" on storage.objects for select to authenticated
  using (bucket_id = 'covers' and yg_can_read_cover_file(name));

-- ---- Profile images ---------------------------------------------------------------

-- Returns { profile, previous } so the app can delete the replaced file.
create or replace function set_profile_image(kind text, value text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  previous text;
  result profiles;
begin
  value := nullif(trim(coalesce(value, '')), '');
  if kind = 'avatar' then
    -- A public URL of a file in your own folder of the "avatars" bucket.
    if value is not null and value not like '%/storage/v1/object/public/avatars/' || me::text || '/%' then
      raise exception 'yg:forbidden:No puedes usar esa imagen.';
    end if;
    select avatar_url into previous from profiles where id = me;
    update profiles set avatar_url = value where id = me returning * into result;
  elsif kind = 'cover' then
    if value is not null and split_part(value, '/', 1) <> me::text then
      raise exception 'yg:forbidden:No puedes usar esa imagen.';
    end if;
    select cover_path into previous from profiles where id = me;
    update profiles set cover_path = value where id = me returning * into result;
  else
    raise exception 'yg:validation:Tipo de imagen no válido.';
  end if;
  return jsonb_build_object('profile', to_jsonb(result), 'previous', previous);
end;
$$;

-- ---- Editable profile fields ----------------------------------------------------------
-- The town is optional: without it there is no "Cerca de ti". Coordinates come
-- with the town from the geocoder and are never shown to other people.

create or replace function update_my_profile(
  first_name text, last_name text, bio text, birthday date, studies text, work text,
  city text, city_lat double precision, city_lng double precision
) returns profiles
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  result profiles;
begin
  first_name := trim(coalesce(first_name, ''));
  last_name := trim(coalesce(last_name, ''));
  city := trim(coalesce(city, ''));
  if char_length(first_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu nombre (máximo 40 caracteres).'; end if;
  if char_length(last_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu apellido (máximo 40 caracteres).'; end if;
  if char_length(trim(coalesce(bio, ''))) > 300 then raise exception 'yg:validation:La biografía no puede superar los 300 caracteres.'; end if;
  if char_length(trim(coalesce(studies, ''))) > 80 or char_length(trim(coalesce(work, ''))) > 80 then
    raise exception 'yg:validation:Estudios y trabajo no pueden superar los 80 caracteres.';
  end if;
  if birthday is not null and (birthday > current_date or birthday < date '1900-01-01') then
    raise exception 'yg:validation:Escribe una fecha de cumpleaños válida.';
  end if;
  if city <> '' and (char_length(city) > 60 or city_lat is null or city_lng is null) then
    raise exception 'yg:validation:Elige tu ciudad o pueblo de la lista.';
  end if;
  update profiles p set
    first_name = update_my_profile.first_name,
    last_name = update_my_profile.last_name,
    bio = trim(coalesce(update_my_profile.bio, '')),
    birthday = update_my_profile.birthday,
    studies = trim(coalesce(update_my_profile.studies, '')),
    work = trim(coalesce(update_my_profile.work, '')),
    city = update_my_profile.city,
    city_lat = case when update_my_profile.city = '' then null else update_my_profile.city_lat end,
    city_lng = case when update_my_profile.city = '' then null else update_my_profile.city_lng end
  where p.id = me
  returning * into result;
  return result;
end;
$$;

grant execute on function set_profile_image(text, text) to authenticated;
grant execute on function update_my_profile(text, text, text, date, text, text, text, double precision, double precision) to authenticated;

-- ---- Profile page: cover path when visible, birthday without the year for others -----

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
    select * into latest from posts where author_id = target and kind = 'status' limit 1;
  end if;
  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', p.id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'avatar_url', p.avatar_url,
      'cover_path', case when visible then p.cover_path end,
      'city', case when can_view_city(me, target) then p.city else '' end,
      -- Coordinates, the full birth date and the visit counter only go to their owner.
      'city_lat', case when me = target then p.city_lat end,
      'city_lng', case when me = target then p.city_lng end,
      'visit_count', case when me = target then p.visit_count end,
      'bio', case when visible then p.bio else '' end,
      'birthday', case when me = target then p.birthday end,
      'birthday_day', case when visible and p.birthday is not null then to_char(p.birthday, 'MM-DD') end,
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
