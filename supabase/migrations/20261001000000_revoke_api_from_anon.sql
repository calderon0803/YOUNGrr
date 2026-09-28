-- Supabase grants EXECUTE on new functions to anon explicitly, so revoking from
-- PUBLIC is not enough. The API is only for signed-in users.
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'people_view(uuid[])', 'profile_view(uuid)', 'search_people(text, int)', 'friend_suggestions(int)',
    'list_friends(uuid)', 'list_friend_requests()', 'send_friend_request(uuid)', 'cancel_friend_request(uuid)',
    'answer_friend_request(uuid, boolean)', 'remove_friend(uuid)', 'register_visit(uuid)',
    'accept_friend_request(uuid)', 'start_conversation(uuid)', 'leave_photo(uuid)',
    'nearby_posts(int, timestamptz, int)'
  ] loop
    execute format('revoke execute on function %s from anon', fn);
    execute format('revoke execute on function %s from public', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;
