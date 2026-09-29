-- Accounts created by hand (from the SQL editor) start with a temporary name
-- and password: the app makes them complete their profile and choose a new
-- password before anything else. Until then they are not offered to others.

alter table profiles add column needs_setup boolean not null default false;

-- Name and town, then the account is ready. The password is changed through
-- Supabase Auth by the app just before.
create or replace function complete_profile_setup(first_name text, last_name text, city text, city_lat double precision, city_lng double precision)
returns profiles
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  result profiles;
begin
  first_name := trim(coalesce(first_name, ''));
  last_name := trim(coalesce(last_name, ''));
  city := trim(coalesce(city, ''));
  if char_length(first_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu nombre (máximo 40 caracteres).'; end if;
  if char_length(last_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu apellido (máximo 40 caracteres).'; end if;
  if char_length(city) not between 1 and 60 or city_lat is null or city_lng is null then
    raise exception 'yg:validation:Elige tu ciudad o pueblo de la lista.';
  end if;
  update profiles p set
    first_name = complete_profile_setup.first_name,
    last_name = complete_profile_setup.last_name,
    city = complete_profile_setup.city,
    city_lat = complete_profile_setup.city_lat,
    city_lng = complete_profile_setup.city_lng,
    needs_setup = false
  where p.id = me
  returning * into result;
  return result;
end;
$$;

grant execute on function complete_profile_setup(text, text, text, double precision, double precision) to authenticated;

-- People search and suggestions skip accounts that are not set up yet.
create or replace function search_people(q text, max_results int default 30) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id),
  found as (
    select p.id, mutual_friends(me.id, p.id) as mutual
    from profiles p, me
    where p.id <> me.id
      and not p.needs_setup
      and length(trim(q)) > 0
      and yg_fold(p.first_name || ' ' || p.last_name || ' ' || case when can_view_city(me.id, p.id) then p.city else '' end)
          like '%' || yg_fold(trim(q)) || '%'
    order by mutual desc, p.first_name
    limit least(max_results, 50)
  )
  select people_view(coalesce(array_agg(id), '{}')) from found;
$$;

create or replace function friend_suggestions(max_results int default 5) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id),
  found as (
    select p.id, mutual_friends(me.id, p.id) as mutual
    from profiles p, me
    where p.id <> me.id
      and not p.needs_setup
      and friendship_status(me.id, p.id) = 'none'
      and mutual_friends(me.id, p.id) > 0
      and can_send_request(me.id, p.id)
    order by mutual desc
    limit least(max_results, 20)
  )
  select people_view(coalesce(array_agg(id), '{}')) from found;
$$;
