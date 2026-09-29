-- Profile visits: only the counter. YOUNGrr no longer stores who visited whom,
-- when, or how many times each person did. The history is deleted.

create or replace function register_visit(profile uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or profile = auth.uid() or not can_view_profile(auth.uid(), profile) then
    return;
  end if;
  update profiles set visit_count = visit_count + 1 where id = profile;
end;
$$;

drop table if exists profile_visits;
