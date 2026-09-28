-- Photos, albums, tags and co-owned photos API, plus "X ha subido N fotos al
-- álbum Y" items in the friends' news. Photos have no permissions of their own:
-- they follow their owners' profile privacy (see can_view_photo).

-- ---- Album uploads as news items ----------------------------------------------------

alter table posts add column kind text not null default 'post' check (kind in ('post', 'album_upload'));
alter table posts add column album_id uuid references albums (id) on delete cascade;
alter table posts add column photo_ids uuid[] not null default '{}';
alter table posts drop constraint if exists posts_check;
alter table posts add constraint posts_has_content
  check (char_length(text) > 0 or photo_id is not null or kind = 'album_upload');

-- ---- Storage: a shared photo can be read through any of its owners -----------------

drop policy if exists "read photos you can see" on storage.objects;
create policy "read photos you can see" on storage.objects for select to authenticated
  using (
    bucket_id = 'photos'
    and (
      can_view_profile(auth.uid(), ((storage.foldername(name))[1])::uuid)
      or exists (select 1 from photos ph where ph.storage_path = name and can_view_photo(auth.uid(), ph.id))
    )
  );

-- Owners of a photo, the uploader always first.
create or replace function yg_photo_owner_ids(photo uuid) returns uuid[]
language sql stable security definer set search_path = public as $$
  select array_agg(u order by ord, responded) from (
    select owner_id as u, 0 as ord, null::timestamptz as responded from photos where id = photo
    union all
    select o.user_id, 1, o.responded_at from photo_owners o
    where o.photo_id = photo and o.status = 'accepted'
      and o.user_id <> (select owner_id from photos where id = photo)
  ) owners;
$$;

-- ---- JSON views ----------------------------------------------------------------------

create or replace function person_summary(target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', p.id, 'first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url)
  from profiles p where p.id = target;
$$;

create or replace function photo_json(me uuid, target uuid, with_comments boolean default false) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', ph.id,
    'owner_id', ph.owner_id,
    'album_id', ph.album_id,
    'storage_path', ph.storage_path,
    'width', ph.width,
    'height', ph.height,
    'caption', ph.caption,
    'created_at', ph.created_at,
    'owner', person_summary(ph.owner_id),
    'owners', (select jsonb_agg(person_summary(u)) from unnest(yg_photo_owner_ids(ph.id)) as u),
    'is_owner', me = any(yg_photo_owner_ids(ph.id)),
    'is_uploader', ph.owner_id = me,
    'pending_owners', case when me = any(yg_photo_owner_ids(ph.id)) then coalesce((
      select jsonb_agg(person_summary(o.user_id)) from photo_owners o where o.photo_id = ph.id and o.status = 'pending'
    ), '[]'::jsonb) else '[]'::jsonb end,
    'owner_invite', (
      select jsonb_build_object('invited_by', person_summary(o.invited_by))
      from photo_owners o where o.photo_id = ph.id and o.user_id = me and o.status = 'pending'
    ),
    'album_title', a.title,
    'album_kind', a.kind,
    -- The album page itself follows the uploader's profile.
    'album_accessible', can_view_profile(me, ph.owner_id),
    'grr_count', (select count(*) from grrs g where g.photo_id = ph.id),
    'has_grr', exists (select 1 from grrs g where g.photo_id = ph.id and g.user_id = me),
    'comment_count', (select count(*) from comments c where c.photo_id = ph.id),
    'tags', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'photo_id', t.photo_id, 'user_id', t.user_id, 'tagged_by', t.tagged_by, 'x', t.x, 'y', t.y,
        'created_at', t.created_at, 'person', person_summary(t.user_id)
      ) order by t.created_at)
      from photo_tags t where t.photo_id = ph.id
    ), '[]'::jsonb),
    'comments', case when with_comments then comments_json(null, ph.id, null) end
  )
  from photos ph join albums a on a.id = ph.album_id
  where ph.id = target;
$$;

-- Counts and cover only include the photos the viewer may see.
create or replace function album_json(me uuid, target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  with visible as (
    select ph.* from photos ph where ph.album_id = target and can_view_photo(me, ph.id)
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

create or replace function photos_json(me uuid, ids uuid[]) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(photo_json(me, t.id) order by t.ord), '[]'::jsonb)
  from unnest(ids) with ordinality as t(id, ord);
$$;

-- News items now include album uploads (with up to six photos still visible).
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
      select jsonb_build_object('id', al.id, 'title', al.title) from albums al where al.id = po.album_id
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

-- Album uploads only exist while their photos do: they cannot be edited.
create or replace function update_post(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  po posts;
begin
  select * into po from posts where id = target;
  if po.id is null then raise exception 'yg:not_found:Esta publicación ya no existe.'; end if;
  if po.author_id <> me then raise exception 'yg:forbidden:Solo puedes editar tus publicaciones.'; end if;
  if po.kind = 'album_upload' then raise exception 'yg:forbidden:Esta novedad no se puede editar.'; end if;
  body := trim(coalesce(body, ''));
  if body = '' and po.photo_id is null then raise exception 'yg:validation:La publicación no puede quedar vacía.'; end if;
  if char_length(body) > 2000 then raise exception 'yg:validation:La publicación no puede superar los 2000 caracteres.'; end if;
  update posts set text = body, updated_at = now() where id = target;
  return post_json(me, target);
end;
$$;

-- ---- Reading ---------------------------------------------------------------------------

create or replace function list_albums(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not can_view_profile(me, target) then raise exception 'yg:forbidden:Este perfil es privado.'; end if;
  return coalesce((
    select jsonb_agg(j order by (j ->> 'updated_at') desc)
    from (select album_json(me, a.id) as j from albums a where a.owner_id = target) x
    where j ->> 'kind' = 'user' or (j ->> 'photo_count')::int > 0
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
      select array_agg(id order by created_at) from photos where album_id = target and can_view_photo(me, id)
    ), '{}')),
    'can_edit', al.owner_id = me
  );
end;
$$;

create or replace function get_photo(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  owner uuid;
begin
  select owner_id into owner from photos where id = target;
  if owner is null then raise exception 'yg:not_found:Esta fotografía ya no existe.'; end if;
  if not can_view_photo(me, target) then
    raise exception 'yg:forbidden:No tienes acceso a este contenido.' using detail = owner::text;
  end if;
  return photo_json(me, target, true);
end;
$$;

-- Photos someone owns: uploaded by them or shared with them.
create or replace function list_user_photos(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not can_view_profile(me, target) then raise exception 'yg:forbidden:Este perfil es privado.'; end if;
  return photos_json(me, coalesce((
    select array_agg(id order by created_at desc) from photos ph
    where target = any(yg_photo_owner_ids(ph.id)) and can_view_photo(me, ph.id)
  ), '{}'));
end;
$$;

create or replace function list_tagged_photos(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not can_view_profile(me, target) then raise exception 'yg:forbidden:Este perfil es privado.'; end if;
  return photos_json(me, coalesce((
    select array_agg(ph.id order by ph.created_at desc) from photos ph
    where exists (select 1 from photo_tags t where t.photo_id = ph.id and t.user_id = target)
      and can_view_photo(me, ph.id)
  ), '{}'));
end;
$$;

create or replace function list_friends_photos(max_results int default 24) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select photos_json(me.id, coalesce((
    select array_agg(id order by created_at desc) from (
      select ph.id, ph.created_at from photos ph
      where exists (select 1 from unnest(yg_photo_owner_ids(ph.id)) o where are_friends(me.id, o))
        and not (me.id = any(yg_photo_owner_ids(ph.id)))
        and can_view_photo(me.id, ph.id)
      order by ph.created_at desc
      limit least(max_results, 60)
    ) recent
  ), '{}'))
  from me;
$$;

-- ---- Albums ----------------------------------------------------------------------------

create or replace function yg_check_album(title text, description text) returns void
language plpgsql immutable as $$
begin
  if trim(coalesce(title, '')) = '' then raise exception 'yg:validation:El nombre del álbum es obligatorio.'; end if;
  if char_length(title) > 60 then raise exception 'yg:validation:El nombre del álbum no puede superar los 60 caracteres.'; end if;
  if char_length(coalesce(description, '')) > 300 then raise exception 'yg:validation:La descripción no puede superar los 300 caracteres.'; end if;
end;
$$;

create or replace function create_album(title text, description text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  perform yg_check_album(title, description);
  insert into albums (owner_id, kind, title, description) values (me, 'user', trim(title), trim(coalesce(description, ''))) returning id into new_id;
  return album_json(me, new_id);
end;
$$;

create or replace function update_album(target uuid, title text, description text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_check_album(title, description);
  update albums set title = trim(update_album.title), description = trim(coalesce(update_album.description, '')), updated_at = now()
  where id = target and owner_id = me and kind = 'user';
  if not found then raise exception 'yg:forbidden:Solo puedes modificar tus álbumes.'; end if;
  return album_json(me, target);
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
  if not exists (select 1 from photos where id = photo and album_id = target) then
    raise exception 'yg:not_found:La foto no está en este álbum.';
  end if;
  update albums set cover_photo_id = photo where id = target;
  return album_json(me, target);
end;
$$;

-- ---- Photos -----------------------------------------------------------------------------

-- Removes the photo from the caller; returns { result, storage_path } where the
-- path is set only when the file must be deleted (no owner left).
create or replace function delete_photo(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  path text;
  result text;
begin
  select storage_path into path from photos where id = target;
  if path is null then raise exception 'yg:not_found:Esta fotografía ya no existe.'; end if;
  if not is_photo_owner(me, target) then raise exception 'yg:forbidden:Solo los dueños de la foto pueden hacer esto.'; end if;
  result := leave_photo(target);
  if result = 'deleted' then
    delete from notifications where target_id = target;
  else
    -- The photo stays with the other owners; only your own notices about it go.
    delete from notifications where target_id = target and user_id = me;
  end if;
  return jsonb_build_object('result', result, 'storage_path', case when result = 'deleted' then path end);
end;
$$;

-- Removes an album: shared photos move to another owner, the rest are deleted.
-- Returns the Storage paths to delete.
create or replace function delete_album(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  ph photos;
  paths text[] := '{}';
  outcome jsonb;
begin
  if not exists (select 1 from albums where id = target and owner_id = me and kind = 'user') then
    raise exception 'yg:forbidden:Este álbum no se puede eliminar.';
  end if;
  for ph in select * from photos where album_id = target loop
    outcome := delete_photo(ph.id);
    if outcome ->> 'storage_path' is not null then paths := paths || (outcome ->> 'storage_path'); end if;
  end loop;
  delete from albums where id = target;
  return to_jsonb(paths);
end;
$$;

-- items: [{ "path": "<me>/<file>", "width": 1200, "height": 800, "caption": "" }]
create or replace function add_photos(target uuid, items jsonb, co_owner_ids uuid[] default '{}') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  al albums;
  item jsonb;
  friend uuid;
  new_id uuid;
  added uuid[] := '{}';
  i int := 0;
begin
  select * into al from albums where id = target;
  if al.id is null or al.owner_id <> me then raise exception 'yg:forbidden:Solo puedes modificar tus álbumes.'; end if;
  if jsonb_array_length(coalesce(items, '[]'::jsonb)) = 0 then raise exception 'yg:validation:Elige al menos una fotografía.'; end if;
  foreach friend in array coalesce(co_owner_ids, '{}') loop
    if not are_friends(me, friend) then raise exception 'yg:forbidden:Solo puedes compartir la foto con tus amigos.'; end if;
  end loop;

  for item in select * from jsonb_array_elements(items) loop
    if split_part(item ->> 'path', '/', 1) <> me::text then raise exception 'yg:forbidden:No puedes subir esa fotografía.'; end if;
    if char_length(coalesce(item ->> 'caption', '')) > 200 then raise exception 'yg:validation:El pie de foto no puede superar los 200 caracteres.'; end if;
    insert into photos (owner_id, album_id, storage_path, width, height, caption, created_at)
    values (me, target, item ->> 'path', (item ->> 'width')::int, (item ->> 'height')::int, trim(coalesce(item ->> 'caption', '')),
            now() + make_interval(secs => i * 0.001))
    returning id into new_id;
    added := added || new_id;
    i := i + 1;
    foreach friend in array coalesce(co_owner_ids, '{}') loop
      insert into photo_owners (photo_id, user_id, invited_by) values (new_id, friend, me) on conflict do nothing;
    end loop;
  end loop;
  update albums set updated_at = now() where id = target;

  -- "X ha subido N fotos al álbum Y" in the friends' news.
  if al.kind = 'user' then
    insert into posts (author_id, text, kind, album_id, photo_ids) values (me, '', 'album_upload', target, added);
  end if;
  return photos_json(me, added);
end;
$$;

create or replace function update_photo_caption(target uuid, caption text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not is_photo_owner(me, target) then raise exception 'yg:forbidden:Solo los dueños de la foto pueden hacer esto.'; end if;
  if char_length(coalesce(caption, '')) > 200 then raise exception 'yg:validation:El pie de foto no puede superar los 200 caracteres.'; end if;
  update photos set caption = trim(coalesce(update_photo_caption.caption, '')) where id = target;
  return photo_json(me, target);
end;
$$;

-- ---- Tags: only owners tag, each one themselves or their own friends ----------------------

create or replace function add_photo_tag(target uuid, person uuid, x real, y real) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  if not exists (select 1 from photos where id = target) then raise exception 'yg:not_found:Esta fotografía ya no existe.'; end if;
  if not is_photo_owner(me, target) then raise exception 'yg:forbidden:Solo pueden etiquetar los dueños de la foto.'; end if;
  if person <> me and not are_friends(me, person) then raise exception 'yg:forbidden:Solo puedes etiquetar a tus amigos.'; end if;
  if exists (select 1 from photo_tags where photo_id = target and user_id = person) then
    raise exception 'yg:conflict:Esta persona ya está etiquetada en la foto.';
  end if;
  if x not between 0 and 1 or y not between 0 and 1 then raise exception 'yg:validation:Posición de etiqueta no válida.'; end if;
  insert into photo_tags (photo_id, user_id, tagged_by, x, y) values (target, person, me, x, y) returning id into new_id;
  return (
    select jsonb_build_object('id', t.id, 'photo_id', t.photo_id, 'user_id', t.user_id, 'tagged_by', t.tagged_by, 'x', t.x, 'y', t.y,
      'created_at', t.created_at, 'person', person_summary(t.user_id))
    from photo_tags t where t.id = new_id
  );
end;
$$;

create or replace function remove_photo_tag(target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  t photo_tags;
begin
  select * into t from photo_tags where id = target;
  if t.id is null then raise exception 'yg:not_found:La etiqueta ya no existe.'; end if;
  if t.user_id <> me and not is_photo_owner(me, t.photo_id) then raise exception 'yg:forbidden:No puedes quitar esta etiqueta.'; end if;
  delete from photo_tags where id = target;
  delete from notifications where type = 'photo_tag' and user_id = t.user_id and target_id = t.photo_id;
end;
$$;

-- ---- Co-ownership --------------------------------------------------------------------------

create or replace function invite_photo_owners(target uuid, people uuid[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  person uuid;
  invited int := 0;
begin
  if not is_photo_owner(me, target) then raise exception 'yg:forbidden:Solo los dueños de la foto pueden hacer esto.'; end if;
  if coalesce(array_length(people, 1), 0) = 0 then raise exception 'yg:validation:Elige al menos a una persona.'; end if;
  foreach person in array people loop
    if not are_friends(me, person) then raise exception 'yg:forbidden:Solo puedes compartir la foto con tus amigos.'; end if;
    if not (person = any(yg_photo_owner_ids(target)))
       and not exists (select 1 from photo_owners where photo_id = target and user_id = person and status = 'pending') then
      insert into photo_owners (photo_id, user_id, invited_by) values (target, person, me)
      on conflict (photo_id, user_id) do update set status = 'pending', invited_by = me, created_at = now(), responded_at = null;
      invited := invited + 1;
    end if;
  end loop;
  return jsonb_build_object('photo', photo_json(me, target, true), 'invited', invited);
end;
$$;

create or replace function answer_photo_owner_invite(target uuid, accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  inviter uuid;
begin
  select invited_by into inviter from photo_owners where photo_id = target and user_id = me and status = 'pending';
  if inviter is null then raise exception 'yg:not_found:Esta invitación ya no está disponible.'; end if;
  update photo_owners set status = case when accept then 'accepted' else 'rejected' end::photo_owner_status, responded_at = now()
  where photo_id = target and user_id = me;
  if accept then perform push_notification(inviter, me, 'photo_owner_accepted', target); end if;
  return case when can_view_photo(me, target) then photo_json(me, target, true) end;
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'list_albums(uuid)', 'get_album(uuid)', 'get_photo(uuid)', 'list_user_photos(uuid)', 'list_tagged_photos(uuid)',
    'list_friends_photos(int)', 'create_album(text, text)', 'update_album(uuid, text, text)', 'set_album_cover(uuid, uuid)',
    'delete_photo(uuid)', 'delete_album(uuid)', 'add_photos(uuid, jsonb, uuid[])', 'update_photo_caption(uuid, text)',
    'add_photo_tag(uuid, uuid, real, real)', 'remove_photo_tag(uuid)', 'invite_photo_owners(uuid, uuid[])',
    'answer_photo_owner_invite(uuid, boolean)'
  ] loop
    execute format('revoke execute on function %s from public', fn);
    execute format('revoke execute on function %s from anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;
