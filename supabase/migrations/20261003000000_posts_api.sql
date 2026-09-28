-- Posts, comments and Grr API. Computed as the caller with the existing privacy
-- helpers (posts follow the author's profile privacy). Photos are returned with
-- their Storage path; the app signs the URLs.

-- A few people who made Grr, friends first ("Ana, Pablo y 3 más").
create or replace function grr_by_json(viewer uuid, post uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url)), '[]'::jsonb)
  from (
    select g.user_id
    from grrs g
    where g.post_id = post and g.user_id <> viewer
    order by are_friends(viewer, g.user_id) desc, g.created_at desc
    limit 2
  ) top
  join profiles p on p.id = top.user_id;
$$;

create or replace function comments_json(target_post uuid, target_photo uuid, last_n int) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(c order by c ->> 'created_at'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', c.id,
      'target_type', case when c.post_id is not null then 'post' else 'photo' end,
      'target_id', coalesce(c.post_id, c.photo_id),
      'author_id', c.author_id,
      'text', c.text,
      'created_at', c.created_at,
      'author', jsonb_build_object('id', p.id, 'first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url)
    ) as c
    from comments c
    join profiles p on p.id = c.author_id
    where (target_post is not null and c.post_id = target_post) or (target_photo is not null and c.photo_id = target_photo)
    order by c.created_at desc
    limit coalesce(last_n, 1000000)
  ) latest;
$$;

create or replace function post_json(viewer uuid, post_id uuid, comment_preview int default 3) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', po.id,
    'author_id', po.author_id,
    'text', po.text,
    'photo_id', po.photo_id,
    'created_at', po.created_at,
    'updated_at', po.updated_at,
    'author', jsonb_build_object('id', a.id, 'first_name', a.first_name, 'last_name', a.last_name, 'avatar_url', a.avatar_url),
    'photo', case when ph.id is null then null else jsonb_build_object(
      'id', ph.id, 'storage_path', ph.storage_path, 'width', ph.width, 'height', ph.height, 'album_id', ph.album_id
    ) end,
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

-- Page of posts, newest first: returns page_size + 1 items so the app knows if there is more.
create or replace function posts_page(ids uuid[]) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(post_json(yg_me(), t.id) order by t.ord), '[]'::jsonb)
  from unnest(ids) with ordinality as t(id, ord);
$$;

-- Friends' activity and your own; no strangers, no ranking.
create or replace function get_feed(before timestamptz default null, page_size int default 8) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select posts_page(coalesce(array_agg(id order by created_at desc), '{}'))
  from (
    select po.id, po.created_at
    from posts po, me
    where (po.author_id = me.id or are_friends(me.id, po.author_id))
      and can_view_post(me.id, po.author_id)
      and not exists (select 1 from hidden_posts h where h.user_id = me.id and h.post_id = po.id)
      and (before is null or po.created_at < before)
    order by po.created_at desc
    limit least(page_size, 30) + 1
  ) page;
$$;

create or replace function get_user_posts(target uuid, before timestamptz default null, page_size int default 8) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not can_view_profile(me, target) then
    raise exception 'yg:forbidden:Este perfil es privado.';
  end if;
  return posts_page(coalesce((
    select array_agg(id order by created_at desc)
    from (
      select po.id, po.created_at from posts po
      where po.author_id = target and (before is null or po.created_at < before)
      order by po.created_at desc
      limit least(page_size, 30) + 1
    ) page
  ), '{}'));
end;
$$;

-- "Cerca de ti": town and distance follow their own privacy settings; the
-- distance is only given when the town is hidden.
create or replace function get_nearby_feed(radius_km int, before timestamptz default null, page_size int default 8) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  origin profiles;
  items jsonb;
begin
  if radius_km not in (10, 25, 50) then
    raise exception 'yg:validation:Radio no válido.';
  end if;
  select * into origin from profiles where id = me;
  if origin.city_lat is null or origin.city_lng is null then
    return jsonb_build_object('needs_location', true, 'origin_city', '', 'items', '[]'::jsonb);
  end if;

  select coalesce(jsonb_agg(
    post_json(me, page.id) || jsonb_build_object('nearby', jsonb_build_object(
      'city', case when can_view_city(me, page.author_id) then page.city end,
      'distance_km', case when not can_view_city(me, page.author_id) and can_view_distance(me, page.author_id) then round(page.km)::int end
    ))
    order by page.created_at desc
  ), '[]'::jsonb)
  into items
  from (
    select po.id, po.created_at, po.author_id, a.city,
           distance_km(origin.city_lat, origin.city_lng, a.city_lat, a.city_lng) as km
    from posts po
    join profiles a on a.id = po.author_id
    where a.id <> me
      and a.city_lat is not null and a.city_lng is not null
      and distance_km(origin.city_lat, origin.city_lng, a.city_lat, a.city_lng) <= radius_km
      and can_view_post(me, a.id)
      and not exists (select 1 from hidden_posts h where h.user_id = me and h.post_id = po.id)
      and (before is null or po.created_at < before)
    order by po.created_at desc
    limit least(page_size, 30) + 1
  ) page;

  return jsonb_build_object('needs_location', false, 'origin_city', origin.city, 'items', items);
end;
$$;

create or replace function get_post(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  author uuid;
begin
  select author_id into author from posts where id = target;
  if author is null then
    raise exception 'yg:not_found:Esta publicación ya no existe.';
  end if;
  if not can_view_post(me, author) then
    -- The app sends the viewer to the author's profile (id in the error detail).
    raise exception 'yg:forbidden:No tienes acceso a este contenido.' using detail = author::text;
  end if;
  return post_json(me, target, null);
end;
$$;

-- ---- Writing posts -----------------------------------------------------------

-- The photo (if any) was already uploaded to Storage at <me>/<file>.
create or replace function create_post(body text, photo_path text default null, photo_width int default null, photo_height int default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  wall uuid;
  new_photo uuid;
  new_post uuid;
begin
  body := trim(coalesce(body, ''));
  if body = '' and photo_path is null then
    raise exception 'yg:validation:Escribe algo o añade una fotografía.';
  end if;
  if char_length(body) > 2000 then
    raise exception 'yg:validation:La publicación no puede superar los 2000 caracteres.';
  end if;
  if photo_path is not null then
    if split_part(photo_path, '/', 1) <> me::text then
      raise exception 'yg:forbidden:No puedes publicar esa fotografía.';
    end if;
    select id into wall from albums where owner_id = me and kind = 'wall';
    insert into photos (owner_id, album_id, storage_path, width, height, caption)
    values (me, wall, photo_path, photo_width, photo_height, left(body, 200))
    returning id into new_photo;
    update albums set updated_at = now() where id = wall;
  end if;
  insert into posts (author_id, text, photo_id) values (me, body, new_photo) returning id into new_post;
  return post_json(me, new_post);
end;
$$;

create or replace function update_post(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  po posts;
begin
  select * into po from posts where id = target;
  if po.id is null then raise exception 'yg:not_found:Esta publicación ya no existe.'; end if;
  if po.author_id <> me then raise exception 'yg:forbidden:Solo puedes editar tus publicaciones.'; end if;
  body := trim(coalesce(body, ''));
  if body = '' and po.photo_id is null then raise exception 'yg:validation:La publicación no puede quedar vacía.'; end if;
  if char_length(body) > 2000 then raise exception 'yg:validation:La publicación no puede superar los 2000 caracteres.'; end if;
  update posts set text = body, updated_at = now() where id = target;
  return post_json(me, target);
end;
$$;

-- Returns the Storage path of a wall photo removed with the post, so the app deletes the file.
create or replace function delete_post(target uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  po posts;
  ph photos;
begin
  select * into po from posts where id = target;
  if po.id is null then raise exception 'yg:not_found:Esta publicación ya no existe.'; end if;
  if po.author_id <> me then raise exception 'yg:forbidden:Solo puedes eliminar tus publicaciones.'; end if;
  select * into ph from photos where id = po.photo_id;
  delete from notifications where target_id = target;
  delete from posts where id = target;
  -- A photo published from the wall goes away with its post.
  if ph.id is not null and exists (select 1 from albums where id = ph.album_id and kind = 'wall') then
    delete from notifications where target_id = ph.id;
    delete from photos where id = ph.id;
    return ph.storage_path;
  end if;
  return null;
end;
$$;

create or replace function hide_post(target uuid, hidden boolean) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if hidden then
    insert into hidden_posts (user_id, post_id) values (me, target) on conflict do nothing;
  else
    delete from hidden_posts where user_id = me and post_id = target;
  end if;
end;
$$;

create or replace function report_post(target uuid, reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if trim(coalesce(reason, '')) = '' then raise exception 'yg:validation:El motivo es obligatorio.'; end if;
  if not exists (select 1 from posts where id = target) then raise exception 'yg:not_found:Esta publicación ya no existe.'; end if;
  insert into reports (reporter_id, post_id, reason) values (me, target, reason);
  insert into hidden_posts (user_id, post_id) values (me, target) on conflict do nothing;
end;
$$;

-- ---- Grr and comments (posts and photos) --------------------------------------

-- Checks the viewer can see the target and returns its owners.
create or replace function yg_target_owners(me uuid, target_type text, target uuid) returns uuid[]
language plpgsql stable security definer set search_path = public as $$
declare
  author uuid;
begin
  if target_type = 'post' then
    select author_id into author from posts where id = target;
    if author is null then raise exception 'yg:not_found:Esta publicación ya no existe.'; end if;
    if not can_view_post(me, author) then raise exception 'yg:forbidden:No puedes ver esta publicación.'; end if;
    return array[author];
  elsif target_type = 'photo' then
    if not exists (select 1 from photos where id = target) then raise exception 'yg:not_found:Esta fotografía ya no existe.'; end if;
    if not can_view_photo(me, target) then raise exception 'yg:forbidden:No puedes ver esta fotografía.'; end if;
    return (
      select array_agg(u) from (
        select owner_id as u from photos where id = target
        union
        select user_id from photo_owners where photo_id = target and status = 'accepted'
      ) owners
    );
  end if;
  raise exception 'yg:validation:Tipo de contenido no válido.';
end;
$$;

-- Makes or removes a Grr. Idempotent thanks to the unique indexes; removing never notifies.
create or replace function set_grr(target_type text, target uuid, value boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_target_owners(me, target_type, target);
  if value then
    if target_type = 'post' then
      insert into grrs (user_id, post_id) values (me, target) on conflict do nothing;
    else
      insert into grrs (user_id, photo_id) values (me, target) on conflict do nothing;
    end if;
  else
    delete from grrs where user_id = me and (post_id = target or photo_id = target);
  end if;
  return jsonb_build_object(
    'grr_count', (select count(*) from grrs where post_id = target or photo_id = target),
    'has_grr', exists (select 1 from grrs where user_id = me and (post_id = target or photo_id = target))
  );
end;
$$;

create or replace function list_grrers(target_type text, target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_target_owners(me, target_type, target);
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url) order by g.created_at desc)
    from grrs g join profiles p on p.id = g.user_id
    where g.post_id = target or g.photo_id = target
  ), '[]'::jsonb);
end;
$$;

create or replace function list_comments(target_type text, target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_target_owners(me, target_type, target);
  if target_type = 'post' then return comments_json(target, null, null); end if;
  return comments_json(null, target, null);
end;
$$;

create or replace function add_comment(target_type text, target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  perform yg_target_owners(me, target_type, target);
  body := trim(coalesce(body, ''));
  if body = '' then raise exception 'yg:validation:El comentario es obligatorio.'; end if;
  if char_length(body) > 500 then raise exception 'yg:validation:El comentario no puede superar los 500 caracteres.'; end if;
  if target_type = 'post' then
    insert into comments (author_id, post_id, text) values (me, target, body) returning id into new_id;
  else
    insert into comments (author_id, photo_id, text) values (me, target, body) returning id into new_id;
  end if;
  return (
    select jsonb_build_object(
      'id', c.id, 'target_type', target_type, 'target_id', target, 'author_id', c.author_id, 'text', c.text, 'created_at', c.created_at,
      'author', jsonb_build_object('id', p.id, 'first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url)
    )
    from comments c join profiles p on p.id = c.author_id where c.id = new_id
  );
end;
$$;

-- The author of the comment or any owner of the content can delete it.
create or replace function delete_comment(target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  c comments;
  owners uuid[];
begin
  select * into c from comments where id = target;
  if c.id is null then raise exception 'yg:not_found:Este comentario ya no existe.'; end if;
  owners := yg_target_owners(me, case when c.post_id is not null then 'post' else 'photo' end, coalesce(c.post_id, c.photo_id));
  if c.author_id <> me and not (me = any(owners)) then
    raise exception 'yg:forbidden:No puedes eliminar este comentario.';
  end if;
  delete from comments where id = target;
  -- Without comments left from that author, their "comentó" notification goes too.
  if not exists (select 1 from comments where author_id = c.author_id and coalesce(post_id, photo_id) = coalesce(c.post_id, c.photo_id)) then
    delete from notifications
    where actor_id = c.author_id and target_id = coalesce(c.post_id, c.photo_id) and type in ('comment_post', 'comment_photo');
  end if;
end;
$$;

-- Grr and comments notify every owner of a shared photo, not only the uploader.
create or replace function on_grr_insert() returns trigger language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
begin
  if new.post_id is not null then
    perform push_notification((select author_id from posts where id = new.post_id), new.user_id, 'grr_post', new.post_id);
  else
    foreach owner in array yg_photo_owner_ids(new.photo_id) loop
      perform push_notification(owner, new.user_id, 'grr_photo', new.photo_id);
    end loop;
  end if;
  return new;
end;
$$;

create or replace function on_comment_insert() returns trigger language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
begin
  if new.post_id is not null then
    perform push_notification((select author_id from posts where id = new.post_id), new.author_id, 'comment_post', new.post_id);
  else
    foreach owner in array yg_photo_owner_ids(new.photo_id) loop
      perform push_notification(owner, new.author_id, 'comment_photo', new.photo_id);
    end loop;
  end if;
  return new;
end;
$$;

create or replace function yg_photo_owner_ids(photo uuid) returns uuid[]
language sql stable security definer set search_path = public as $$
  select array_agg(u) from (
    select owner_id as u from photos where id = photo
    union
    select user_id from photo_owners where photo_id = photo and status = 'accepted'
  ) owners;
$$;

-- Only signed-in users call the API.
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'get_feed(timestamptz, int)', 'get_user_posts(uuid, timestamptz, int)', 'get_nearby_feed(int, timestamptz, int)',
    'get_post(uuid)', 'create_post(text, text, int, int)', 'update_post(uuid, text)', 'delete_post(uuid)',
    'hide_post(uuid, boolean)', 'report_post(uuid, text)', 'set_grr(text, uuid, boolean)', 'list_grrers(text, uuid)',
    'list_comments(text, uuid)', 'add_comment(text, uuid, text)', 'delete_comment(uuid)', 'posts_page(uuid[])'
  ] loop
    execute format('revoke execute on function %s from public', fn);
    execute format('revoke execute on function %s from anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;
