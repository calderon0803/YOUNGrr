-- Images of groups. Place groups show the flag of their community or province
-- (towns, the one of their province); the app has them, so only the key of the
-- place is needed. Groups made by people can have an image, set by their owner
-- and administrators; it is seen by whoever can see the group.

alter table groups add column image_path text;
create unique index groups_image_path_key on groups (image_path) where image_path is not null;

-- Returns { group, removed_path }: the previous image, when it was yours, for
-- the app to delete it.
create or replace function set_group_image(target uuid, image_path text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  previous text;
begin
  perform yg_require_group_admin(me, target);
  if (select kind from groups where id = target) <> 'user' then
    raise exception 'yg:forbidden:Los grupos de lugares llevan la bandera de su lugar.';
  end if;
  perform yg_check_own_path(me, image_path);
  select g.image_path into previous from groups g where g.id = target;
  update groups g set image_path = set_group_image.image_path, updated_at = now() where g.id = target;
  return jsonb_build_object(
    'group', group_json(me, target),
    'removed_path', case when previous is distinct from image_path and split_part(previous, '/', 1) = me::text then previous end
  );
end;
$$;
grant execute on function set_group_image(uuid, text) to authenticated;

create or replace function group_json(me uuid, g uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', gr.id,
    'kind', gr.kind,
    'privacy', gr.privacy,
    'name', gr.name,
    'description', gr.description,
    'created_at', gr.created_at,
    'place_level', gr.place_level,
    -- Place groups show the flag of their place (or of the place above).
    'place_key', gr.place_key,
    'image_path', gr.image_path,
    'parent', (select jsonb_build_object('id', p.id, 'name', p.name, 'place_key', p.place_key) from groups p where p.id = gr.parent_id),
    'owner', (select person_summary(o.user_id) from group_members o where o.group_id = gr.id and o.role = 'owner'),
    'member_count', yg_group_member_count(gr.id),
    'my_role', x.my_role,
    'can_manage', yg_is_group_admin(gr.id, me),
    -- Your settings in this group.
    'my_settings', (select jsonb_build_object('profile_share', m.profile_share, 'notify', m.notify, 'hidden', m.hidden)
                    from group_members m where m.group_id = gr.id and m.user_id = me),
    'invited_by', (select person_summary(i.invited_by) from group_invites i where i.group_id = gr.id and i.user_id = me),
    'requested', exists (select 1 from group_join_requests r where r.group_id = gr.id and r.user_id = me),
    'request_count', case when x.my_role in ('owner', 'admin') then (select count(*) from group_join_requests r where r.group_id = gr.id) else 0 end,
    -- What the counters show, following your notices for this group.
    'new_posts', case when yg_group_notify(gr.id, me) = 'all' then yg_group_new_posts(me, gr.id) else 0 end,
    'mentions', case when yg_group_notify(gr.id, me) in ('all', 'mentions') then yg_group_mentions(me, gr.id) else 0 end,
    'last_post_at', case when x.my_role is not null then (select max(p.created_at) from group_posts p where p.group_id = gr.id) end,
    'expires_at', case when x.my_role = 'owner' and gr.kind = 'user' and gr.first_joined_at is null then gr.created_at + interval '7 days' end
  )
  from groups gr, lateral (select yg_group_role(gr.id, me) as my_role) x
  where gr.id = g;
$$;

create or replace function delete_group(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  paths jsonb;
begin
  perform yg_require_group_member(me, target);
  if yg_group_role(target, me) <> 'owner' then raise exception 'yg:forbidden:Solo quien es propietario del grupo puede eliminarlo.'; end if;
  select coalesce(jsonb_agg(photo_path), '[]'::jsonb) into paths
  from group_posts where group_id = target and author_id = me and photo_path is not null;
  -- Its image too, when it is in your folder.
  select paths || coalesce((select jsonb_agg(image_path) from groups where id = target and split_part(image_path, '/', 1) = me::text), '[]'::jsonb)
  into paths;
  delete from groups where id = target;
  return paths;
end;
$$;

-- Group images follow who can see the group.
create or replace function yg_can_read_photo_file(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select split_part(path, '/', 1) = auth.uid()::text
    or exists (select 1 from photos ph where ph.storage_path = path and can_view_photo(auth.uid(), ph.id))
    or exists (select 1 from events e where e.image_path = path and can_see_event(auth.uid(), e.id))
    or exists (
      select 1 from group_posts p where p.photo_path = path
        and yg_is_group_member(p.group_id, auth.uid()) and not is_blocked_between(auth.uid(), p.author_id))
    or exists (select 1 from groups g where g.image_path = path and can_see_group(auth.uid(), g.id))
    or (is_moderator() and exists (select 1 from reports r where r.snapshot ->> 'storage_path' = path));
$$;

create or replace function admin_storage_orphans() returns table (bucket text, path text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select o.bucket_id, o.name, o.created_at
  from storage.objects o
  where o.bucket_id in ('photos', 'avatars', 'covers')
    and o.created_at < now() - interval '1 day'
    and not (
      (o.bucket_id = 'photos' and (
        exists (select 1 from photos ph where ph.storage_path = o.name)
        or exists (select 1 from events e where e.image_path = o.name)
        or exists (select 1 from group_posts p where p.photo_path = o.name)
        or exists (select 1 from groups g where g.image_path = o.name)
        or exists (select 1 from reports r where r.snapshot ->> 'storage_path' = o.name and r.status = 'pending')
        -- Removed photos that can still be appealed.
        or exists (select 1 from moderation_removals m where m.storage_path = o.name and not yg_removal_final(m))))
      or (o.bucket_id = 'avatars' and exists (select 1 from profiles p where p.avatar_url like '%/avatars/' || o.name))
      or (o.bucket_id = 'covers' and exists (select 1 from profiles p where p.cover_path = o.name))
    )
  order by o.created_at;
$$;
revoke execute on function admin_storage_orphans() from public, anon, authenticated;
