-- "Quizá conozcas a" shows 3 people and a "Ver todas" list: up to 100
-- suggestions, people with at least one friend in common, most in common first
-- (then by name). Like the search, limited per minute: the list shows friends
-- of friends and must not serve to map who knows whom.
create or replace function yg_friend_suggestions(me uuid, max_results int) returns jsonb
language sql stable security definer set search_path = public as $$
  with found as (
    select p.id, mutual_friends(me, p.id) as mutual, p.first_name, p.last_name
    from profiles p
    where p.id <> me
      and not p.needs_setup
      and friendship_status(me, p.id) = 'none'
      and mutual_friends(me, p.id) > 0
      and can_send_request(me, p.id)
    order by mutual desc, p.first_name, p.last_name
    limit least(max_results, 100)
  )
  select people_view(coalesce(array_agg(id order by mutual desc, first_name, last_name), '{}')) from found;
$$;

drop function if exists friend_suggestions(int);

create or replace function friend_suggestions(max_results int default 5) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_rate_limit('suggestions', 20);
  return yg_friend_suggestions(me, max_results);
end;
$$;

grant execute on function friend_suggestions(int) to authenticated;
