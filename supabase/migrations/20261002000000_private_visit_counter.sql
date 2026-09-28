-- The visit counter is private: only the owner sees it (on their home page).

-- Nobody can read another user's counter from the table.
revoke select (visit_count) on profiles from authenticated;

-- Registering a visit no longer tells the visitor the total.
drop function if exists register_visit(uuid);

create function register_visit(profile uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  counted int;
begin
  if auth.uid() is null or profile = auth.uid() or not can_view_profile(auth.uid(), profile) then
    return;
  end if;
  insert into profile_visits (profile_id, visitor_id) values (profile, auth.uid()) on conflict do nothing;
  get diagnostics counted = row_count;
  if counted > 0 then
    update profiles set visit_count = visit_count + 1 where id = profile;
  end if;
end;
$$;

revoke execute on function register_visit(uuid) from public;
revoke execute on function register_visit(uuid) from anon;
grant execute on function register_visit(uuid) to authenticated;

-- Same profile page data, with the counter only for the owner.
create or replace function profile_view(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p profiles;
  visible boolean;
begin
  select * into p from profiles where id = target;
  if not found then
    raise exception 'yg:not_found:Esta persona no existe o ha eliminado su cuenta.';
  end if;
  visible := can_view_profile(me, target);
  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', p.id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'avatar_url', p.avatar_url,
      'cover_url', case when visible then p.cover_url end,
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
    'visits', case when me = target then p.visit_count end
  );
end;
$$;
