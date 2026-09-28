-- Sign-up also stores the town coordinates picked in the registration form, and
-- each user can read their own full profile (other users only get the columns
-- granted on `profiles` and what `profile_details` allows).

create or replace function on_auth_user_created() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, first_name, last_name, city, city_lat, city_lng)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce(new.raw_user_meta_data ->> 'city', ''),
    nullif(new.raw_user_meta_data ->> 'city_lat', '')::double precision,
    nullif(new.raw_user_meta_data ->> 'city_lng', '')::double precision
  );
  insert into user_settings (user_id) values (new.id);
  insert into albums (owner_id, kind, title, description) values (new.id, 'wall', 'Fotos del muro', 'Fotografías publicadas en el muro.');
  return new;
end;
$$;

-- The signed-in user's own profile, including town coordinates.
create or replace function my_profile() returns profiles
language sql stable security definer set search_path = public as $$
  select * from profiles where id = auth.uid();
$$;

revoke execute on function my_profile() from anon;
grant execute on function my_profile() to authenticated;
