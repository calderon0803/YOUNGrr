-- Supabase grants EXECUTE on every new function to anon and authenticated.
-- Internal helpers that take the viewer as a parameter (post_json, photo_json,
-- push_notification...) must not be callable through the API: someone could
-- pass another person's id and read private content or send notifications.
--
-- From now on: nothing is executable by default, the app's API is granted to
-- signed-in users, and so are the helpers that row-level security policies call
-- (policies run with the caller's privileges).

-- PUBLIC's default EXECUTE is global: it can only be removed without IN SCHEMA.
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon;
alter default privileges in schema public revoke execute on functions from authenticated;

do $$
declare
  fn regprocedure;
  api text[] := array[
    'add_comment', 'add_photo_tag', 'add_photos', 'add_wall_message', 'answer_friend_request',
    'answer_photo_owner_invite', 'cancel_friend_request', 'create_album', 'create_event', 'create_post',
    'delete_album', 'delete_comment', 'delete_event', 'delete_photo', 'delete_post', 'delete_wall_message',
    'friend_suggestions', 'get_album', 'get_conversation', 'get_event', 'get_feed', 'get_nearby_feed',
    'get_photo', 'get_post', 'get_user_posts', 'global_search', 'hide_post', 'invite_photo_owners',
    'invite_to_event', 'list_albums', 'list_comments', 'list_conversations', 'list_events',
    'list_friend_requests', 'list_friends', 'list_friends_photos', 'list_grrers', 'list_tagged_photos',
    'list_user_photos', 'list_wall', 'mark_conversation_read', 'mark_notifications_seen', 'my_profile',
    'notification_state', 'profile_view', 'register_visit', 'remove_friend', 'remove_photo_tag',
    'report_post', 'respond_event', 'search_people', 'send_friend_request', 'send_message',
    'set_album_cover', 'set_grr', 'start_conversation', 'unread_conversations', 'upcoming_birthdays',
    'update_album', 'update_event', 'update_photo_caption', 'update_post'
  ];
begin
  -- Every function of ours in public (not the ones extensions own).
  for fn in
    select p.oid::regprocedure
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn);
  end loop;

  -- The API and the helpers used by row-level security policies (any schema,
  -- including storage).
  for fn in
    select p.oid::regprocedure
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prokind = 'f'
      and (
        p.proname = any(api)
        or exists (
          select 1 from pg_policies pol
          where coalesce(pol.qual, '') ~ ('\m' || p.proname || '\(')
             or coalesce(pol.with_check, '') ~ ('\m' || p.proname || '\(')
        )
      )
  loop
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;
