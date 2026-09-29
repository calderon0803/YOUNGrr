-- Every photo is uploaded to the owner's default album ("Mis fotos", which
-- cannot be deleted). The other albums are collections: photos already
-- uploaded are added to them (a photo can be in several) and nothing is
-- uploaded to them directly.
--
-- - The default album is the old 'wall' album (one per person, created at sign up).
-- - photos.album_id always points to the uploader's default album.
-- - album_photos says which photos are in each of the other albums.
-- - Deleting an album can keep its photos, delete the ones only in that album,
--   or delete all of them.

insert into albums (owner_id, kind, title, description)
select p.id, 'wall', 'Mis fotos', '' from profiles p
where not exists (select 1 from albums a where a.owner_id = p.id and a.kind = 'wall');

update albums set title = 'Mis fotos', description = '' where kind = 'wall';

create table album_photos (
  album_id uuid not null references albums (id) on delete cascade,
  photo_id uuid not null references photos (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (album_id, photo_id)
);
create index album_photos_photo on album_photos (photo_id);
alter table album_photos enable row level security;
revoke all on table album_photos from authenticated, anon;

-- Photos in the albums of today go to their owner's default album and stay in
-- the album they were in.
insert into album_photos (album_id, photo_id, added_at)
select ph.album_id, ph.id, ph.created_at
from photos ph join albums a on a.id = ph.album_id
where a.kind = 'user';

update photos ph set album_id = w.id
from albums a, albums w
where a.id = ph.album_id and a.kind = 'user' and w.owner_id = ph.owner_id and w.kind = 'wall';

-- New accounts get "Mis fotos".
create or replace function on_auth_user_created() returns trigger language plpgsql security definer set search_path = public as $$
declare
  accepted boolean := (new.raw_user_meta_data ->> 'terms_version') is not distinct from yg_terms_version();
begin
  insert into profiles (id, first_name, last_name, city, city_lat, city_lng, adult_confirmed_at, terms_version, terms_accepted_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce(new.raw_user_meta_data ->> 'city', ''),
    nullif(new.raw_user_meta_data ->> 'city_lat', '')::double precision,
    nullif(new.raw_user_meta_data ->> 'city_lng', '')::double precision,
    case when (new.raw_user_meta_data ->> 'adult_confirmed') = 'true' then now() end,
    case when accepted then yg_terms_version() end,
    case when accepted then now() end
  );
  insert into user_settings (user_id) values (new.id);
  insert into albums (owner_id, kind, title, description) values (new.id, 'wall', 'Mis fotos', '');
  return new;
end;
$$;

-- ---- Which photos an album holds -------------------------------------------------------------

create or replace function yg_album_photo_ids(target uuid) returns setof uuid
language sql stable security definer set search_path = public as $$
  select ph.id from photos ph join albums a on a.id = target
  where a.kind = 'wall' and ph.album_id = target
  union
  select ap.photo_id from album_photos ap join albums a on a.id = ap.album_id
  where a.kind = 'user' and ap.album_id = target;
$$;

-- Counts and cover only include the photos the viewer may see.
create or replace function album_json(me uuid, target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  with visible as (
    select ph.* from photos ph where ph.id in (select yg_album_photo_ids(target)) and can_view_photo(me, ph.id)
  )
  select jsonb_build_object(
    'id', a.id,
    'owner_id', a.owner_id,
    'kind', a.kind,
    'title', a.title,
    'description', a.description,
    'cover_photo_id', a.cover_photo_id,
    'created_at', a.created_at,
    'updated_at', a.updated_at,
    'owner', person_summary(a.owner_id),
    'cover_path', coalesce(
      (select storage_path from visible where id = a.cover_photo_id),
      (select storage_path from visible order by created_at desc limit 1)
    ),
    'photo_count', (select count(*) from visible)
  )
  from albums a where a.id = target;
$$;

-- "Mis fotos" first, then the other albums by last change.
create or replace function list_albums(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not can_view_profile(me, target) then raise exception 'yg:forbidden:Este perfil es privado.'; end if;
  return coalesce((
    select jsonb_agg(album_json(me, a.id) order by (a.kind = 'wall') desc, a.updated_at desc)
    from albums a where a.owner_id = target
  ), '[]'::jsonb);
end;
$$;

create or replace function get_album(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  al albums;
begin
  select * into al from albums where id = target;
  if al.id is null then raise exception 'yg:not_found:Este álbum ya no existe.'; end if;
  if not can_view_profile(me, al.owner_id) then
    raise exception 'yg:forbidden:No tienes acceso a este contenido.' using detail = al.owner_id::text;
  end if;
  return jsonb_build_object(
    'album', album_json(me, target),
    'photos', photos_json(me, coalesce((
      select array_agg(ph.id order by ph.created_at)
      from photos ph where ph.id in (select yg_album_photo_ids(target)) and can_view_photo(me, ph.id)
    ), '{}')),
    'can_edit', al.owner_id = me
  );
end;
$$;

create or replace function set_album_cover(target uuid, photo uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not exists (select 1 from albums where id = target and owner_id = me) then
    raise exception 'yg:forbidden:Solo puedes modificar tus álbumes.';
  end if;
  if photo not in (select yg_album_photo_ids(target)) then
    raise exception 'yg:not_found:La foto no está en este álbum.';
  end if;
  update albums set cover_photo_id = photo where id = target;
  return album_json(me, target);
end;
$$;

-- ---- Uploading: always to "Mis fotos" --------------------------------------------------------

drop function if exists add_photos(uuid, jsonb, uuid[]);

-- items: [{ "path": "<me>/<file>", "width": 1200, "height": 800, "caption": "" }]
create or replace function upload_photos(items jsonb, co_owner_ids uuid[] default '{}') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  mine uuid;
  item jsonb;
  friend uuid;
  new_id uuid;
  added uuid[] := '{}';
  i int := 0;
begin
  select id into mine from albums where owner_id = me and kind = 'wall';
  if jsonb_array_length(coalesce(items, '[]'::jsonb)) = 0 then raise exception 'yg:validation:Elige al menos una fotografía.'; end if;
  foreach friend in array coalesce(co_owner_ids, '{}') loop
    if not are_friends(me, friend) then raise exception 'yg:forbidden:Solo puedes compartir la foto con tus amigos.'; end if;
  end loop;

  for item in select * from jsonb_array_elements(items) loop
    if split_part(item ->> 'path', '/', 1) <> me::text then raise exception 'yg:forbidden:No puedes subir esa fotografía.'; end if;
    if char_length(coalesce(item ->> 'caption', '')) > 200 then raise exception 'yg:validation:El pie de foto no puede superar los 200 caracteres.'; end if;
    insert into photos (owner_id, album_id, storage_path, width, height, caption, created_at)
    values (me, mine, item ->> 'path', (item ->> 'width')::int, (item ->> 'height')::int, trim(coalesce(item ->> 'caption', '')),
            now() + make_interval(secs => i * 0.001))
    returning id into new_id;
    added := added || new_id;
    i := i + 1;
    foreach friend in array coalesce(co_owner_ids, '{}') loop
      insert into photo_owners (photo_id, user_id, invited_by) values (new_id, friend, me) on conflict do nothing;
    end loop;
  end loop;
  update albums set updated_at = now() where id = mine;

  -- "X ha subido N fotos" in the friends' news.
  insert into posts (author_id, text, kind, album_id, photo_ids) values (me, '', 'album_upload', mine, added);
  return photos_json(me, added);
end;
$$;

-- ---- Adding to and removing from the other albums -------------------------------------------

-- Only photos you own (uploaded or shared with you) go into your albums.
create or replace function add_to_album(target uuid, photo_ids uuid[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  photo uuid;
begin
  if not exists (select 1 from albums where id = target and owner_id = me and kind = 'user') then
    raise exception 'yg:forbidden:Solo puedes añadir fotos a tus álbumes.';
  end if;
  if coalesce(array_length(photo_ids, 1), 0) = 0 then raise exception 'yg:validation:Elige al menos una fotografía.'; end if;
  if array_length(photo_ids, 1) > 200 then raise exception 'yg:validation:Puedes añadir hasta 200 fotos de una vez.'; end if;
  foreach photo in array photo_ids loop
    if not is_photo_owner(me, photo) then raise exception 'yg:forbidden:Solo puedes añadir tus fotos.'; end if;
    insert into album_photos (album_id, photo_id) values (target, photo) on conflict do nothing;
  end loop;
  update albums set updated_at = now() where id = target;
  return album_json(me, target);
end;
$$;

create or replace function remove_from_album(target uuid, photo uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not exists (select 1 from albums where id = target and owner_id = me and kind = 'user') then
    raise exception 'yg:forbidden:Solo puedes modificar tus álbumes.';
  end if;
  delete from album_photos where album_id = target and album_photos.photo_id = photo;
  update albums set cover_photo_id = null where id = target and cover_photo_id = photo;
  return album_json(me, target);
end;
$$;

-- ---- Deleting an album ------------------------------------------------------------------------

-- mode: 'album' (only the album), 'exclusive' (also the photos that are in no
-- other album of yours) or 'all' (also all its photos). Photos shared with
-- other owners stay with them. Returns the Storage paths to delete.
drop function if exists delete_album(uuid);

create or replace function delete_album(target uuid, mode text default 'album') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  photo uuid;
  paths text[] := '{}';
  outcome jsonb;
begin
  if not exists (select 1 from albums where id = target and owner_id = me and kind = 'user') then
    raise exception 'yg:forbidden:Este álbum no se puede eliminar.';
  end if;
  if mode not in ('album', 'exclusive', 'all') then raise exception 'yg:validation:Elige qué quieres eliminar.'; end if;
  for photo in
    select ap.photo_id from album_photos ap
    where ap.album_id = target and mode <> 'album'
      and (mode = 'all' or not exists (
        select 1 from album_photos other join albums a on a.id = other.album_id
        where other.photo_id = ap.photo_id and other.album_id <> target and a.owner_id = me
      ))
      and is_photo_owner(me, ap.photo_id)
  loop
    outcome := delete_photo(photo);
    if outcome ->> 'storage_path' is not null then paths := paths || (outcome ->> 'storage_path'); end if;
  end loop;
  delete from albums where id = target;
  return to_jsonb(paths);
end;
$$;

grant execute on function upload_photos(jsonb, uuid[]) to authenticated;
grant execute on function add_to_album(uuid, uuid[]) to authenticated;
grant execute on function remove_from_album(uuid, uuid) to authenticated;
grant execute on function delete_album(uuid, text) to authenticated;

-- ---- Leaving a photo takes it out of your albums ---------------------------------------------

create or replace function leave_photo(photo uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  ph photos;
  heir uuid;
begin
  select * into ph from photos where id = photo;
  if ph is null or not is_photo_owner(auth.uid(), photo) then raise exception 'not an owner'; end if;

  -- Whoever leaves the photo takes it out of their albums.
  delete from album_photos ap using albums a
  where a.id = ap.album_id and a.owner_id = auth.uid() and ap.photo_id = photo;

  if ph.owner_id <> auth.uid() then
    delete from photo_owners where photo_id = photo and user_id = auth.uid();
    return 'left';
  end if;

  select user_id into heir from photo_owners
  where photo_id = photo and status = 'accepted' order by responded_at limit 1;
  if heir is null then
    delete from photos where id = photo;
    return 'deleted';
  end if;

  update albums set cover_photo_id = null where cover_photo_id = photo;
  update photos
     set owner_id = heir,
         album_id = (select id from albums where owner_id = heir and kind = 'wall')
   where id = photo;
  delete from photo_owners where photo_id = photo and user_id = heir;
  return 'left';
end;
$$;

-- ---- News items: the album kind, to say "ha subido N fotos" for Mis fotos -------------------

create or replace function post_json(viewer uuid, post_id uuid, comment_preview int default 3) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', po.id,
    'kind', po.kind,
    'author_id', po.author_id,
    'text', po.text,
    'photo_id', po.photo_id,
    'created_at', po.created_at,
    'updated_at', po.updated_at,
    'author', jsonb_build_object('id', a.id, 'first_name', a.first_name, 'last_name', a.last_name, 'avatar_url', a.avatar_url),
    'photo', case when ph.id is null then null else jsonb_build_object(
      'id', ph.id, 'storage_path', ph.storage_path, 'width', ph.width, 'height', ph.height, 'album_id', ph.album_id
    ) end,
    'album', case when po.album_id is null then null else (
      select jsonb_build_object('id', al.id, 'title', al.title, 'kind', al.kind) from albums al where al.id = po.album_id
    ) end,
    'photos', case when po.kind = 'album_upload' then coalesce((
      select jsonb_agg(jsonb_build_object('id', p2.id, 'storage_path', p2.storage_path, 'width', p2.width, 'height', p2.height) order by t.ord)
      from unnest(po.photo_ids) with ordinality as t(id, ord)
      join photos p2 on p2.id = t.id
      where t.ord <= 6
    ), '[]'::jsonb) else '[]'::jsonb end,
    'photo_total', case when po.kind = 'album_upload' then (select count(*) from photos p3 where p3.id = any(po.photo_ids)) else 0 end,
    'grr_count', (select count(*) from grrs g where g.post_id = po.id),
    'has_grr', exists (select 1 from grrs g where g.post_id = po.id and g.user_id = viewer),
    'grr_by', grr_by_json(viewer, po.id),
    'comment_count', (select count(*) from comments c where c.post_id = po.id),
    'comments', comments_json(po.id, null, comment_preview)
  )
  from posts po
  join profiles a on a.id = po.author_id
  left join photos ph on ph.id = po.photo_id
  where po.id = post_json.post_id;
$$;

-- ---- Data export: which photos each album holds ---------------------------------------------

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
        'adult_confirmed_at', p.adult_confirmed_at, 'terms_version', p.terms_version, 'terms_accepted_at', p.terms_accepted_at
      ) from profiles p, me where p.id = me.id
    ),
    'settings', (select to_jsonb(s) - 'user_id' from user_settings s, me where s.user_id = me.id),
    'status', (select jsonb_build_object('text', po.text, 'created_at', po.created_at) from posts po, me where po.author_id = me.id and po.kind = 'status'),
    'albums', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'description', a.description, 'kind', a.kind, 'created_at', a.created_at,
        'photo_ids', (select coalesce(jsonb_agg(x), '[]'::jsonb) from yg_album_photo_ids(a.id) x)) order by a.created_at)
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
    -- Whole conversations: what the person wrote and what they received in them.
    'conversations', coalesce((select jsonb_agg(jsonb_build_object(
        'with', (select coalesce(jsonb_agg(p.first_name || ' ' || p.last_name), '[]'::jsonb) from conversation_members cm join profiles p on p.id = cm.user_id
                 where cm.conversation_id = c.conversation_id and cm.user_id <> c.user_id),
        'messages', coalesce((select jsonb_agg(jsonb_build_object(
            'from', case when m.sender_id = c.user_id then 'yo' else (select p.first_name || ' ' || p.last_name from profiles p where p.id = m.sender_id) end,
            'text', case when m.deleted_at is null then m.text end,
            'deleted', m.deleted_at is not null,
            'created_at', m.created_at) order by m.created_at)
          from messages m where m.conversation_id = c.conversation_id), '[]'::jsonb)))
      from conversation_members c, me where c.user_id = me.id), '[]'::jsonb),
    'invitations_sent', coalesce((select jsonb_agg(jsonb_build_object('email', i.email, 'created_at', i.created_at, 'expires_at', i.expires_at, 'used', i.used_by is not null))
      from invitations i, me where i.inviter_id = me.id), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('about', r.target_type, 'reason', r.reason, 'status', r.status, 'created_at', r.created_at))
      from reports r, me where r.reporter_id = me.id), '[]'::jsonb)
  );
$$;
