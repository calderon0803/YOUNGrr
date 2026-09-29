-- Audit R01, R02, R03: the database, not the app, enforces the business rules.
--
-- Every write goes through the security definer RPCs (which validate it); the
-- tables only keep the read policies clients need. A Storage path can only be
-- recorded by its own folder's owner, and private files are only readable
-- through a row the reader is allowed to see.

-- ---- Nothing is writable directly (the RPCs run as the table owner) ---------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'friendships', 'friend_requests', 'albums', 'photos', 'photo_owners', 'posts',
    'photo_tags', 'grrs', 'comments', 'hidden_posts', 'reports', 'events', 'event_members',
    'conversations', 'conversation_members', 'messages', 'notifications', 'wall_messages', 'invitations'
  ] loop
    execute format('revoke insert, update, delete, truncate on table %I from authenticated, anon', t);
  end loop;
end;
$$;

drop policy if exists "own profile insert" on profiles;
drop policy if exists "own profile update" on profiles;
drop policy if exists "remove own friendship" on friendships;
drop policy if exists "send request" on friend_requests;
drop policy if exists "sender cancels, recipient rejects" on friend_requests;
drop policy if exists "albums owner writes" on albums;
drop policy if exists "uploader inserts photos" on photos;
drop policy if exists "owners update photos" on photos;
drop policy if exists "owners invite friends" on photo_owners;
drop policy if exists "invitee answers" on photo_owners;
drop policy if exists "co-owner leaves" on photo_owners;
drop policy if exists "own posts insert" on posts;
drop policy if exists "own posts update" on posts;
drop policy if exists "own posts delete" on posts;
drop policy if exists "uploader tags self or friends" on photo_tags;
drop policy if exists "untag: tagged person or owner" on photo_tags;
drop policy if exists "make grr" on grrs;
drop policy if exists "remove own grr" on grrs;
drop policy if exists "comment on visible content" on comments;
drop policy if exists "delete: author or content owner" on comments;
drop policy if exists "own hidden posts" on hidden_posts;
create policy "own hidden posts" on hidden_posts for select to authenticated using (user_id = auth.uid());
drop policy if exists "file reports" on reports;
drop policy if exists "create events" on events;
drop policy if exists "creator edits" on events;
drop policy if exists "creator deletes" on events;
drop policy if exists "invite friends" on event_members;
drop policy if exists "answer own invitation" on event_members;
drop policy if exists "mark own read" on conversation_members;
drop policy if exists "members send messages" on messages;
drop policy if exists "mark own notifications" on notifications;
drop policy if exists "owner and friends write" on wall_messages;
drop policy if exists "author or owner delete" on wall_messages;

-- Settings stay editable by their owner, but only the settings themselves.
revoke insert, update, delete, truncate on table user_settings from authenticated, anon;
grant update (
  profile_visibility, city_visibility, distance_visibility, nearby_radius_km, friend_requests,
  notify_grr, notify_comments, notify_friend_requests, notify_events, notify_messages, notify_tags, theme
) on user_settings to authenticated;

-- The anonymous role never reads or writes tables (defence in depth: RLS already
-- blocks it), now and for tables created later.
revoke all on all tables in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;

-- Unused: it listed every profile to any signed-in user (audit R06).
drop view if exists profile_details;

-- ---- Storage paths belong to their folder's owner -----------------------------------

-- Checked on existing rows too when possible; new rows are always checked.
alter table photos add constraint photos_path_in_owner_folder
  check (split_part(storage_path, '/', 1) = owner_id::text) not valid;
alter table events add constraint events_image_in_creator_folder
  check (image_path is null or split_part(image_path, '/', 1) = creator_id::text) not valid;

do $$
begin
  alter table photos validate constraint photos_path_in_owner_folder;
  alter table events validate constraint events_image_in_creator_folder;
exception when check_violation then
  raise notice 'Hay filas antiguas con rutas fuera de la carpeta del dueño: revísalas a mano.';
end;
$$;

-- One row per file: a path cannot be attached twice.
do $$
begin
  create unique index photos_storage_path_key on photos (storage_path);
  create unique index events_image_path_key on events (image_path) where image_path is not null;
exception when unique_violation then
  raise notice 'Hay rutas de Storage repetidas: revísalas a mano.';
end;
$$;

-- ---- Private files: readable by their owner or through a row you can see ------------
-- Before, any file in the folder of someone whose profile you could see was
-- readable (including images of events you were not invited to).

-- The check runs as definer: Storage policies are evaluated with the caller's
-- privileges, and must not depend on columns or tables the caller cannot read.
create or replace function yg_can_read_photo_file(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select split_part(path, '/', 1) = auth.uid()::text
    or exists (select 1 from photos ph where ph.storage_path = path and can_view_photo(auth.uid(), ph.id))
    or exists (
      select 1 from events e
      where e.image_path = path and (e.creator_id = auth.uid() or is_event_member(e.id, auth.uid()))
    );
$$;
grant execute on function yg_can_read_photo_file(text) to authenticated;

drop policy if exists "read photos you can see" on storage.objects;
drop policy if exists "read event images" on storage.objects;
create policy "read photos you can see" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and yg_can_read_photo_file(name));
