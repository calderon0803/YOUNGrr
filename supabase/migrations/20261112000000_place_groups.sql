-- Place groups, instead of "Cerca de ti".
--
-- - Every autonomous community and province of Spain has its group (a community
--   of a single province, like Cantabria, is one group). Anyone joins them
--   directly; there is no member limit and they do not count as groups you created.
-- - Municipalities are not created by people, so there are no empty groups of
--   towns without anyone in YOUNGrr: whoever wants one asks for it ("Quiero un
--   grupo de…", the town picked from the list of the geocoder, so it cannot be
--   duplicated). Only how many asked is shown, never who. When 5 people have
--   asked (app_settings.place_group_threshold), the group is created, they are
--   all in and they get a notice. A request not fulfilled in 90 days expires.
-- - YOUNGrr's moderators administer them (and can name administrators among their
--   members). The members list only shows the total and, by name, your friends
--   (and who administers it).
-- - "Cerca de ti" goes away, and with it the radius and distance settings. The
--   town of a profile stays as a name: its coordinates had no other use and are
--   no longer kept.

-- ---- "Cerca de ti" goes -----------------------------------------------------------------------

drop function if exists nearby_activity(int, timestamptz, int);
drop function if exists get_nearby_feed(int, timestamptz, int);
drop function if exists nearby_posts(int, timestamptz, int);
drop function if exists can_view_distance(uuid, uuid);
drop function if exists distance_km(double precision, double precision, double precision, double precision);
alter table user_settings drop column if exists distance_visibility;
alter table user_settings drop column if exists nearby_radius_km;

-- Coordinates are never kept (whatever sends them).
update profiles set city_lat = null, city_lng = null where city_lat is not null or city_lng is not null;

create or replace function on_profile_drop_coordinates() returns trigger
language plpgsql as $$
begin
  new.city_lat := null;
  new.city_lng := null;
  return new;
end;
$$;
create trigger profiles_no_coordinates before insert or update on profiles
  for each row execute function on_profile_drop_coordinates();

-- A town is only its name now (the app still makes you pick it from the list).
create or replace function update_my_profile(
  first_name text, last_name text, bio text, birthday date, studies text, work text,
  city text, city_lat double precision, city_lng double precision
) returns profiles
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
  if char_length(trim(coalesce(bio, ''))) > 300 then raise exception 'yg:validation:La biografía no puede superar los 300 caracteres.'; end if;
  if char_length(trim(coalesce(studies, ''))) > 80 or char_length(trim(coalesce(work, ''))) > 80 then
    raise exception 'yg:validation:Estudios y trabajo no pueden superar los 80 caracteres.';
  end if;
  if birthday is not null and (birthday > current_date or birthday < date '1900-01-01') then
    raise exception 'yg:validation:Escribe una fecha de cumpleaños válida.';
  end if;
  if char_length(city) > 60 then raise exception 'yg:validation:Elige tu ciudad o pueblo de la lista.'; end if;
  update profiles p set
    first_name = update_my_profile.first_name,
    last_name = update_my_profile.last_name,
    bio = trim(coalesce(update_my_profile.bio, '')),
    birthday = update_my_profile.birthday,
    studies = trim(coalesce(update_my_profile.studies, '')),
    work = trim(coalesce(update_my_profile.work, '')),
    city = update_my_profile.city
  where p.id = me
  returning * into result;
  return result;
end;
$$;

create or replace function complete_profile_setup(first_name text, last_name text, city text, city_lat double precision, city_lng double precision)
returns profiles
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me_setup();
  result profiles;
begin
  first_name := trim(coalesce(first_name, ''));
  last_name := trim(coalesce(last_name, ''));
  city := trim(coalesce(city, ''));
  if char_length(first_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu nombre (máximo 40 caracteres).'; end if;
  if char_length(last_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu apellido (máximo 40 caracteres).'; end if;
  if char_length(city) > 60 then raise exception 'yg:validation:Elige tu ciudad o pueblo de la lista.'; end if;
  update profiles p set
    first_name = complete_profile_setup.first_name,
    last_name = complete_profile_setup.last_name,
    city = complete_profile_setup.city,
    needs_setup = false
  where p.id = me
  returning * into result;
  return result;
end;
$$;

-- ---- Place groups -----------------------------------------------------------------------------

alter table groups
  add column place_level text check (place_level in ('community', 'province', 'municipality')),
  add column place_key text,
  add column parent_id uuid references groups (id) on delete set null,
  add constraint groups_place_fields check ((kind = 'place') = (place_level is not null and place_key is not null));
create unique index groups_place_key on groups (place_key) where place_key is not null;
create index groups_parent on groups (parent_id) where parent_id is not null;

insert into app_settings (key, value) values ('place_group_threshold', '5') on conflict (key) do nothing;

-- Communities and provinces (same keys as src/config/places.js).
with places (place_key, name, place_level, parent_key) as (values
  ('es-andalucia', 'Andalucía', 'community', null),
  ('es-almeria', 'Almería', 'province', 'es-andalucia'),
  ('es-cadiz', 'Cádiz', 'province', 'es-andalucia'),
  ('es-cordoba', 'Córdoba', 'province', 'es-andalucia'),
  ('es-granada', 'Granada', 'province', 'es-andalucia'),
  ('es-huelva', 'Huelva', 'province', 'es-andalucia'),
  ('es-jaen', 'Jaén', 'province', 'es-andalucia'),
  ('es-malaga', 'Málaga', 'province', 'es-andalucia'),
  ('es-sevilla', 'Sevilla', 'province', 'es-andalucia'),
  ('es-aragon', 'Aragón', 'community', null),
  ('es-huesca', 'Huesca', 'province', 'es-aragon'),
  ('es-teruel', 'Teruel', 'province', 'es-aragon'),
  ('es-zaragoza', 'Zaragoza', 'province', 'es-aragon'),
  ('es-asturias', 'Asturias', 'community', null),
  ('es-baleares', 'Illes Balears', 'community', null),
  ('es-canarias', 'Canarias', 'community', null),
  ('es-las-palmas', 'Las Palmas', 'province', 'es-canarias'),
  ('es-santa-cruz-de-tenerife', 'Santa Cruz de Tenerife', 'province', 'es-canarias'),
  ('es-cantabria', 'Cantabria', 'community', null),
  ('es-castilla-la-mancha', 'Castilla-La Mancha', 'community', null),
  ('es-albacete', 'Albacete', 'province', 'es-castilla-la-mancha'),
  ('es-ciudad-real', 'Ciudad Real', 'province', 'es-castilla-la-mancha'),
  ('es-cuenca', 'Cuenca', 'province', 'es-castilla-la-mancha'),
  ('es-guadalajara', 'Guadalajara', 'province', 'es-castilla-la-mancha'),
  ('es-toledo', 'Toledo', 'province', 'es-castilla-la-mancha'),
  ('es-castilla-y-leon', 'Castilla y León', 'community', null),
  ('es-avila', 'Ávila', 'province', 'es-castilla-y-leon'),
  ('es-burgos', 'Burgos', 'province', 'es-castilla-y-leon'),
  ('es-leon', 'León', 'province', 'es-castilla-y-leon'),
  ('es-palencia', 'Palencia', 'province', 'es-castilla-y-leon'),
  ('es-salamanca', 'Salamanca', 'province', 'es-castilla-y-leon'),
  ('es-segovia', 'Segovia', 'province', 'es-castilla-y-leon'),
  ('es-soria', 'Soria', 'province', 'es-castilla-y-leon'),
  ('es-valladolid', 'Valladolid', 'province', 'es-castilla-y-leon'),
  ('es-zamora', 'Zamora', 'province', 'es-castilla-y-leon'),
  ('es-cataluna', 'Cataluña', 'community', null),
  ('es-barcelona', 'Barcelona', 'province', 'es-cataluna'),
  ('es-girona', 'Girona', 'province', 'es-cataluna'),
  ('es-lleida', 'Lleida', 'province', 'es-cataluna'),
  ('es-tarragona', 'Tarragona', 'province', 'es-cataluna'),
  ('es-ceuta', 'Ceuta', 'community', null),
  ('es-comunitat-valenciana', 'Comunitat Valenciana', 'community', null),
  ('es-alicante', 'Alicante', 'province', 'es-comunitat-valenciana'),
  ('es-castellon', 'Castellón', 'province', 'es-comunitat-valenciana'),
  ('es-valencia', 'Valencia', 'province', 'es-comunitat-valenciana'),
  ('es-extremadura', 'Extremadura', 'community', null),
  ('es-badajoz', 'Badajoz', 'province', 'es-extremadura'),
  ('es-caceres', 'Cáceres', 'province', 'es-extremadura'),
  ('es-galicia', 'Galicia', 'community', null),
  ('es-a-coruna', 'A Coruña', 'province', 'es-galicia'),
  ('es-lugo', 'Lugo', 'province', 'es-galicia'),
  ('es-ourense', 'Ourense', 'province', 'es-galicia'),
  ('es-pontevedra', 'Pontevedra', 'province', 'es-galicia'),
  ('es-madrid', 'Comunidad de Madrid', 'community', null),
  ('es-melilla', 'Melilla', 'community', null),
  ('es-murcia', 'Región de Murcia', 'community', null),
  ('es-navarra', 'Navarra', 'community', null),
  ('es-pais-vasco', 'País Vasco', 'community', null),
  ('es-alava', 'Álava', 'province', 'es-pais-vasco'),
  ('es-bizkaia', 'Bizkaia', 'province', 'es-pais-vasco'),
  ('es-gipuzkoa', 'Gipuzkoa', 'province', 'es-pais-vasco'),
  ('es-la-rioja', 'La Rioja', 'community', null)
)
insert into groups (kind, privacy, name, description, place_level, place_key, first_joined_at)
select 'place', 'closed', name, '', place_level, place_key, now() from places;

update groups g set parent_id = p.id
from (values
  ('es-almeria', 'es-andalucia'),
  ('es-cadiz', 'es-andalucia'),
  ('es-cordoba', 'es-andalucia'),
  ('es-granada', 'es-andalucia'),
  ('es-huelva', 'es-andalucia'),
  ('es-jaen', 'es-andalucia'),
  ('es-malaga', 'es-andalucia'),
  ('es-sevilla', 'es-andalucia'),
  ('es-huesca', 'es-aragon'),
  ('es-teruel', 'es-aragon'),
  ('es-zaragoza', 'es-aragon'),
  ('es-las-palmas', 'es-canarias'),
  ('es-santa-cruz-de-tenerife', 'es-canarias'),
  ('es-albacete', 'es-castilla-la-mancha'),
  ('es-ciudad-real', 'es-castilla-la-mancha'),
  ('es-cuenca', 'es-castilla-la-mancha'),
  ('es-guadalajara', 'es-castilla-la-mancha'),
  ('es-toledo', 'es-castilla-la-mancha'),
  ('es-avila', 'es-castilla-y-leon'),
  ('es-burgos', 'es-castilla-y-leon'),
  ('es-leon', 'es-castilla-y-leon'),
  ('es-palencia', 'es-castilla-y-leon'),
  ('es-salamanca', 'es-castilla-y-leon'),
  ('es-segovia', 'es-castilla-y-leon'),
  ('es-soria', 'es-castilla-y-leon'),
  ('es-valladolid', 'es-castilla-y-leon'),
  ('es-zamora', 'es-castilla-y-leon'),
  ('es-barcelona', 'es-cataluna'),
  ('es-girona', 'es-cataluna'),
  ('es-lleida', 'es-cataluna'),
  ('es-tarragona', 'es-cataluna'),
  ('es-alicante', 'es-comunitat-valenciana'),
  ('es-castellon', 'es-comunitat-valenciana'),
  ('es-valencia', 'es-comunitat-valenciana'),
  ('es-badajoz', 'es-extremadura'),
  ('es-caceres', 'es-extremadura'),
  ('es-a-coruna', 'es-galicia'),
  ('es-lugo', 'es-galicia'),
  ('es-ourense', 'es-galicia'),
  ('es-pontevedra', 'es-galicia'),
  ('es-alava', 'es-pais-vasco'),
  ('es-bizkaia', 'es-pais-vasco'),
  ('es-gipuzkoa', 'es-pais-vasco')
) x (child, parent)
join groups p on p.place_key = x.parent
where g.place_key = x.child;

-- Who asked for the group of a town ("Quiero un grupo de…").
create table place_group_requests (
  place_key  text not null check (place_key ~ '^osm-[NWR][0-9]{1,15}$'),
  place_name text not null check (char_length(place_name) between 1 and 80),
  -- The province (or single-province community) the town is in, when known.
  parent_key text,
  user_id    uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (place_key, user_id)
);
create index place_group_requests_user on place_group_requests (user_id);
alter table place_group_requests enable row level security;
revoke all on table place_group_requests from authenticated, anon;
create trigger rate_limit_place_requests before insert on place_group_requests for each row execute function on_rate_limited_insert('place_request', '10');

-- Notices: a group nobody joined was deleted, or a town's group was activated.
alter table group_notices
  add column kind text not null default 'expired' check (kind in ('expired', 'activated')),
  add column group_id uuid references groups (id) on delete cascade;

-- ---- Rules that change for place groups -----------------------------------------------------------

-- Moderators administer every place group they are in.
create or replace function yg_is_group_admin(g uuid, person uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(yg_group_role(g, person) in ('owner', 'admin'), false)
    or (yg_is_group_member(g, person)
        and exists (select 1 from groups where id = g and kind = 'place')
        and exists (select 1 from moderators where user_id = person));
$$;

-- No member limit in place groups.
create or replace function yg_join_group(g uuid, person uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if yg_is_group_member(g, person) then return; end if;
  if (select kind from groups where id = g) = 'user' and yg_group_member_count(g) >= 200 then
    raise exception 'yg:conflict:Este grupo ya tiene 200 personas, el máximo.';
  end if;
  insert into group_members (group_id, user_id, role) values (g, person, 'member');
  delete from group_invites where group_id = g and user_id = person;
  delete from group_join_requests where group_id = g and user_id = person;
end;
$$;

-- A place group stays even when everyone leaves.
create or replace function yg_leave_group(person uuid, g uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  was text := yg_group_role(g, person);
  heir uuid;
begin
  if was is null then return; end if;
  delete from group_members where group_id = g and user_id = person;
  if (select kind from groups where id = g) = 'place' then return; end if;
  if not exists (select 1 from group_members where group_id = g) then
    delete from groups where id = g;
    return;
  end if;
  if was = 'owner' then
    select user_id into heir from group_members where group_id = g
    order by case role when 'admin' then 0 else 1 end, joined_at limit 1;
    update group_members set role = 'owner' where group_id = g and user_id = heir;
  end if;
end;
$$;

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
    'parent', (select jsonb_build_object('id', p.id, 'name', p.name) from groups p where p.id = gr.parent_id),
    'owner', (select person_summary(o.user_id) from group_members o where o.group_id = gr.id and o.role = 'owner'),
    'member_count', yg_group_member_count(gr.id),
    'my_role', x.my_role,
    -- Moderators administer place groups without a role of their own.
    'can_manage', yg_is_group_admin(gr.id, me),
    'invited_by', (select person_summary(i.invited_by) from group_invites i where i.group_id = gr.id and i.user_id = me),
    'requested', exists (select 1 from group_join_requests r where r.group_id = gr.id and r.user_id = me),
    'request_count', case when x.my_role in ('owner', 'admin') then (select count(*) from group_join_requests r where r.group_id = gr.id) else 0 end,
    'new_posts', case when x.my_role is not null then yg_group_new_posts(me, gr.id) else 0 end,
    'last_post_at', case when x.my_role is not null then (select max(p.created_at) from group_posts p where p.group_id = gr.id) end,
    -- Only its owner sees when a group nobody joined will be deleted.
    'expires_at', case when x.my_role = 'owner' and gr.kind = 'user' and gr.first_joined_at is null then gr.created_at + interval '7 days' end
  )
  from groups gr, lateral (select yg_group_role(gr.id, me) as my_role) x
  where gr.id = g;
$$;

-- In place groups you only see the names of your friends (and of who administers it).
create or replace function get_group(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  gr groups := yg_visible_group(me, target);
  inside boolean := yg_is_group_member(target, me);
begin
  return jsonb_build_object(
    'group', group_json(me, target),
    'members', case when inside then coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(m.user_id), 'role', m.role, 'joined_at', m.joined_at)
        order by case m.role when 'owner' then 0 when 'admin' then 1 else 2 end, m.joined_at)
      from group_members m
      where m.group_id = target
        and (m.user_id = me or not is_blocked_between(me, m.user_id))
        and (gr.kind = 'user' or m.user_id = me or m.role <> 'member' or are_friends(me, m.user_id))
    ), '[]'::jsonb) else '[]'::jsonb end,
    'requests', case when yg_is_group_admin(target, me) then coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(r.user_id), 'created_at', r.created_at) order by r.created_at)
      from group_join_requests r where r.group_id = target and not is_blocked_between(me, r.user_id)
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end;
$$;

-- Place groups: anyone joins directly.
create or replace function request_to_join_group(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  gr groups := yg_visible_group(me, target);
begin
  if yg_is_group_member(target, me) then return group_json(me, target); end if;
  if gr.kind = 'place' or exists (select 1 from group_invites where group_id = target and user_id = me) then
    perform yg_join_group(target, me);
  else
    if gr.privacy <> 'closed' then raise exception 'yg:forbidden:A este grupo solo se entra con invitación.'; end if;
    perform yg_rate_limit('group_request', 20);
    insert into group_join_requests (group_id, user_id) values (target, me) on conflict do nothing;
  end if;
  return group_json(me, target);
end;
$$;

-- The name of a place group is the place's.
create or replace function update_group(target uuid, group_name text, about text, secret boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_require_group_admin(me, target);
  perform yg_check_group(group_name, about);
  update groups set
    name = case when kind = 'user' then trim(group_name) else name end,
    description = trim(coalesce(about, '')),
    privacy = case when kind = 'user' then (case when secret then 'secret' else 'closed' end) else privacy end,
    updated_at = now()
  where id = target;
  return group_json(me, target);
end;
$$;

-- User groups: the owner. Place groups: the moderators in them name
-- administrators among the members (there is no owner).
create or replace function set_group_role(target uuid, person uuid, new_role text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  gr groups := yg_visible_group(me, target);
begin
  perform yg_require_group_member(me, target);
  if gr.kind = 'place' then
    if not exists (select 1 from moderators where user_id = me) then
      raise exception 'yg:forbidden:Los grupos de lugares los administra la moderación de YOUNGrr.';
    end if;
    if new_role not in ('admin', 'member') then raise exception 'yg:validation:Papel no válido.'; end if;
  else
    if yg_group_role(target, me) <> 'owner' then raise exception 'yg:forbidden:Solo quien es propietario del grupo puede cambiar los papeles.'; end if;
    if new_role not in ('owner', 'admin', 'member') then raise exception 'yg:validation:Papel no válido.'; end if;
  end if;
  if person = me or not yg_is_group_member(target, person) then raise exception 'yg:validation:Elige a otra persona del grupo.'; end if;
  if new_role = 'owner' then
    update group_members set role = 'admin' where group_id = target and user_id = me;
  end if;
  update group_members set role = new_role where group_id = target and user_id = person;
end;
$$;

-- Moderators in place groups remove members too (never other administrators
-- unless they are moderators as well).
create or replace function remove_group_member(target uuid, person uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  their text := yg_group_role(target, person);
  place boolean := (select kind = 'place' from groups where id = target);
  moderator boolean := exists (select 1 from moderators where user_id = me);
begin
  perform yg_require_group_admin(me, target);
  if person = me then raise exception 'yg:validation:Para irte, sal del grupo.'; end if;
  if their is null then raise exception 'yg:not_found:Esta persona ya no está en el grupo.'; end if;
  if their = 'owner'
     or (their = 'admin' and not (yg_group_role(target, me) = 'owner' or (place and moderator))) then
    raise exception 'yg:forbidden:No puedes quitar a esta persona.';
  end if;
  delete from group_members where group_id = target and user_id = person;
end;
$$;

-- ---- Browsing and asking for place groups --------------------------------------------------------

-- Communities (without parent) or the groups inside one (provinces, towns).
create or replace function list_place_groups(parent uuid default null) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select coalesce(jsonb_agg(group_json(me.id, g.id) order by case g.place_level when 'province' then 0 else 1 end, g.name), '[]'::jsonb)
  from groups g, me
  where g.kind = 'place'
    and ((parent is null and g.parent_id is null and g.place_level = 'community') or g.parent_id = parent);
$$;

-- Your place: the town of your profile (when its group exists) and the groups above it.
create or replace function suggest_place_groups() returns jsonb
language sql stable security definer set search_path = public as $$
  with recursive me as (select yg_me() as id),
  town as (
    select g.id, g.parent_id, 0 as depth from groups g, profiles p, me
    where p.id = me.id and p.city <> '' and g.place_level = 'municipality' and yg_fold(g.name) = yg_fold(p.city)
  ),
  chain as (
    select * from town
    union
    select g.id, g.parent_id, c.depth + 1 from groups g join chain c on g.id = c.parent_id
  )
  select coalesce(jsonb_agg(group_json(me.id, c.id) order by c.depth), '[]'::jsonb)
  from (select distinct on (id) id, depth from chain order by id, depth) c, me;
$$;

create or replace function yg_place_threshold() returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select value::int from app_settings where key = 'place_group_threshold'), 5);
$$;

-- For a town picked from the list: its group if it exists, or how many asked for it.
create or replace function place_group_status(key text) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select jsonb_build_object(
    'group', (select group_json(me.id, g.id) from groups g where g.place_key = key),
    'count', (select count(*) from place_group_requests r where r.place_key = key and r.created_at > now() - interval '90 days'),
    'threshold', yg_place_threshold(),
    'requested', exists (select 1 from place_group_requests r where r.place_key = key and r.user_id = me.id)
  ) from me;
$$;

-- "Quiero un grupo de…". When enough people asked, the group is created with
-- all of them in it. Returns place_group_status().
create or replace function request_place_group(key text, place_name text, parent_key text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  existing uuid;
  parent uuid;
  new_id uuid;
  asked int;
begin
  place_name := trim(coalesce(place_name, ''));
  if coalesce(key, '') !~ '^osm-[NWR][0-9]{1,15}$' or char_length(place_name) not between 1 and 80 then
    raise exception 'yg:validation:Elige el pueblo o la ciudad de la lista.';
  end if;
  select id into existing from groups where place_key = key;
  if existing is not null then
    perform yg_join_group(existing, me);
    return place_group_status(key);
  end if;
  select id into parent from groups where kind = 'place' and place_key = parent_key and place_level in ('community', 'province');
  insert into place_group_requests (place_key, place_name, parent_key, user_id)
  values (key, place_name, case when parent is not null then parent_key end, me)
  on conflict (place_key, user_id) do update set created_at = now(), place_name = excluded.place_name;

  select count(*) into asked from place_group_requests where place_key = key and created_at > now() - interval '90 days';
  if asked >= yg_place_threshold() then
    -- The most repeated name and parent win (a town has one, but just in case).
    insert into groups (kind, privacy, name, description, place_level, place_key, parent_id, first_joined_at)
    values ('place', 'closed',
      (select r.place_name from place_group_requests r where r.place_key = key group by r.place_name order by count(*) desc, r.place_name limit 1),
      '', 'municipality', key,
      (select g.id from place_group_requests r join groups g on g.place_key = r.parent_key where r.place_key = key
       group by g.id order by count(*) desc limit 1),
      now())
    returning id into new_id;
    insert into group_members (group_id, user_id, role)
    select new_id, r.user_id, 'member' from place_group_requests r where r.place_key = key and r.created_at > now() - interval '90 days';
    -- Everyone else who asked is told.
    insert into group_notices (user_id, group_name, kind, group_id)
    select r.user_id, g.name, 'activated', new_id from place_group_requests r, groups g
    where r.place_key = key and g.id = new_id and r.user_id <> me and r.created_at > now() - interval '90 days';
    delete from place_group_requests where place_key = key;
  end if;
  return place_group_status(key);
end;
$$;

create or replace function cancel_place_request(key text) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from place_group_requests where place_key = key and user_id = yg_me();
end;
$$;

-- Your requests, with how many asked (never who) and until when they last.
create or replace function my_place_requests() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select coalesce(jsonb_agg(jsonb_build_object(
      'place_key', r.place_key,
      'place_name', r.place_name,
      'count', (select count(*) from place_group_requests x where x.place_key = r.place_key and x.created_at > now() - interval '90 days'),
      'threshold', yg_place_threshold(),
      'expires_at', r.created_at + interval '90 days'
    ) order by r.created_at desc), '[]'::jsonb)
  from place_group_requests r, me
  where r.user_id = me.id and r.created_at > now() - interval '90 days';
$$;

create or replace function my_group_notices() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'kind', n.kind, 'group_id', n.group_id, 'group_name', n.group_name, 'created_at', n.created_at)
    order by n.created_at desc), '[]'::jsonb)
  from group_notices n where n.user_id = yg_me();
$$;

-- Every night, also: requests for towns older than 90 days go.
create or replace function yg_cleanup_groups() returns int
language plpgsql volatile security definer set search_path = public as $$
declare
  n int;
begin
  insert into group_notices (user_id, group_name)
  select g.created_by, g.name from groups g
  where g.kind = 'user' and g.first_joined_at is null and g.created_at < now() - interval '7 days' and g.created_by is not null;
  delete from groups g where g.kind = 'user' and g.first_joined_at is null and g.created_at < now() - interval '7 days';
  get diagnostics n = row_count;
  delete from group_notices where created_at < now() - interval '30 days';
  delete from place_group_requests where created_at < now() - interval '90 days';
  return n;
end;
$$;
revoke execute on function yg_cleanup_groups() from public, anon, authenticated;

grant execute on function list_place_groups(uuid) to authenticated;
grant execute on function suggest_place_groups() to authenticated;
grant execute on function place_group_status(text) to authenticated;
grant execute on function request_place_group(text, text, text) to authenticated;
grant execute on function cancel_place_request(text) to authenticated;
grant execute on function my_place_requests() to authenticated;

-- ---- Data export: requests for place groups ---------------------------------------------------

create or replace function export_my_data() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me_setup() as id)
  select jsonb_build_object(
    'generated_at', now(),
    'account', (
      select jsonb_build_object('email', u.email, 'created_at', u.created_at, 'last_sign_in_at', u.last_sign_in_at)
      from auth.users u, me where u.id = me.id
    ),
    'profile', (
      select jsonb_build_object(
        'first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url, 'cover_path', p.cover_path,
        'city', p.city, 'city_lat', p.city_lat, 'city_lng', p.city_lng, 'bio', p.bio, 'birthday', p.birthday,
        'studies', p.studies, 'work', p.work, 'visit_count', p.visit_count, 'created_at', p.created_at,
        'adult_confirmed_at', p.adult_confirmed_at, 'terms_version', p.terms_version, 'terms_accepted_at', p.terms_accepted_at
      ) from profiles p, me where p.id = me.id
    ),
    'settings', (select to_jsonb(s) - 'user_id' from user_settings s, me where s.user_id = me.id),
    'status', (select jsonb_build_object('text', po.text, 'created_at', po.created_at) from posts po, me where po.author_id = me.id and po.kind = 'status'),
    'albums', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'description', a.description, 'kind', a.kind, 'created_at', a.created_at,
        'photo_ids', (select coalesce(jsonb_agg(x), '[]'::jsonb) from yg_album_photo_ids(a.id) x)) order by a.created_at)
      from albums a, me where a.owner_id = me.id), '[]'::jsonb),
    'photos', coalesce((select jsonb_agg(jsonb_build_object('id', ph.id, 'album_id', ph.album_id, 'storage_path', ph.storage_path, 'caption', ph.caption, 'width', ph.width, 'height', ph.height, 'created_at', ph.created_at) order by ph.created_at)
      from photos ph, me where ph.owner_id = me.id), '[]'::jsonb),
    'photos_shared_with_me', coalesce((select jsonb_agg(jsonb_build_object('photo_id', o.photo_id, 'status', o.status, 'created_at', o.created_at))
      from photo_owners o, me where o.user_id = me.id), '[]'::jsonb),
    'tags_of_me', coalesce((select jsonb_agg(jsonb_build_object('photo_id', t.photo_id, 'created_at', t.created_at))
      from photo_tags t, me where t.user_id = me.id), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object('text', c.text, 'on', case when c.post_id is not null then 'status' else 'photo' end, 'created_at', c.created_at) order by c.created_at)
      from comments c, me where c.author_id = me.id), '[]'::jsonb),
    'grrs', coalesce((select jsonb_agg(jsonb_build_object('on', case when g.post_id is not null then 'status' else 'photo' end, 'created_at', g.created_at) order by g.created_at)
      from grrs g, me where g.user_id = me.id), '[]'::jsonb),
    'wall_messages_written', coalesce((select jsonb_agg(jsonb_build_object('text', w.text, 'on_profile_of', p.first_name || ' ' || p.last_name, 'created_at', w.created_at) order by w.created_at)
      from wall_messages w join profiles p on p.id = w.profile_id, me where w.author_id = me.id), '[]'::jsonb),
    'wall_messages_received', (select count(*) from wall_messages w, me where w.profile_id = me.id and w.author_id <> me.id),
    'friends', coalesce((select jsonb_agg(jsonb_build_object('name', p.first_name || ' ' || p.last_name, 'since', f.created_at) order by f.created_at)
      from friendships f join profiles p on p.id = case when f.user_a = (select id from me) then f.user_b else f.user_a end, me
      where me.id in (f.user_a, f.user_b)), '[]'::jsonb),
    'friend_requests_sent', coalesce((select jsonb_agg(jsonb_build_object('status', r.status, 'created_at', r.created_at))
      from friend_requests r, me where r.from_id = me.id), '[]'::jsonb),
    'events_created', coalesce((select jsonb_agg(jsonb_build_object('title', e.title, 'description', e.description, 'date', e.date, 'time', e.time, 'location', e.location, 'created_at', e.created_at))
      from events e, me where e.creator_id = me.id), '[]'::jsonb),
    'events_answered', coalesce((select jsonb_agg(jsonb_build_object('event_id', m.event_id, 'status', m.status, 'responded_at', m.responded_at))
      from event_members m, me where m.user_id = me.id), '[]'::jsonb),
    -- Whole conversations: what the person wrote and what they received in them.
    'conversations', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', (select kind from conversations where id = c.conversation_id),
        'title', (select title from conversations where id = c.conversation_id),
        'with', (select coalesce(jsonb_agg(p.first_name || ' ' || p.last_name), '[]'::jsonb) from conversation_members cm join profiles p on p.id = cm.user_id
                 where cm.conversation_id = c.conversation_id and cm.user_id <> c.user_id),
        'messages', coalesce((select jsonb_agg(jsonb_build_object(
            'from', case when m.sender_id = c.user_id then 'yo' else (select p.first_name || ' ' || p.last_name from profiles p where p.id = m.sender_id) end,
            'text', case when m.deleted_at is null then m.text end,
            'deleted', m.deleted_at is not null,
            'created_at', m.created_at) order by m.created_at)
          from messages m where m.conversation_id = c.conversation_id), '[]'::jsonb)))
      from conversation_members c, me where c.user_id = me.id), '[]'::jsonb),
    -- Groups: where the person is and what they wrote in the Gallinero.
    'groups', coalesce((select jsonb_agg(jsonb_build_object('name', g.name, 'privacy', g.privacy, 'role', gm.role, 'joined_at', gm.joined_at) order by gm.joined_at)
      from group_members gm join groups g on g.id = gm.group_id, me where gm.user_id = me.id), '[]'::jsonb),
    'group_posts', coalesce((select jsonb_agg(jsonb_build_object('group', g.name, 'text', gp.text, 'photo_path', gp.photo_path, 'created_at', gp.created_at) order by gp.created_at)
      from group_posts gp join groups g on g.id = gp.group_id, me where gp.author_id = me.id), '[]'::jsonb),
    'group_replies', coalesce((select jsonb_agg(jsonb_build_object('text', gr.text, 'created_at', gr.created_at) order by gr.created_at)
      from group_replies gr, me where gr.author_id = me.id), '[]'::jsonb),
    'group_grrs', coalesce((select jsonb_agg(jsonb_build_object('created_at', gg.created_at) order by gg.created_at)
      from group_post_grrs gg, me where gg.user_id = me.id), '[]'::jsonb),
    'group_requests', coalesce((select jsonb_agg(jsonb_build_object('group', g.name, 'created_at', r.created_at))
      from group_join_requests r join groups g on g.id = r.group_id, me where r.user_id = me.id), '[]'::jsonb),
    'group_invitations_received', coalesce((select jsonb_agg(jsonb_build_object('group', g.name, 'created_at', i.created_at))
      from group_invites i join groups g on g.id = i.group_id, me where i.user_id = me.id), '[]'::jsonb),
    'place_group_requests', coalesce((select jsonb_agg(jsonb_build_object('place', r.place_name, 'created_at', r.created_at) order by r.created_at)
      from place_group_requests r, me where r.user_id = me.id), '[]'::jsonb),
    'invitations_sent', coalesce((select jsonb_agg(jsonb_build_object('email', i.email, 'created_at', i.created_at, 'expires_at', i.expires_at, 'used', i.used_by is not null))
      from invitations i, me where i.inviter_id = me.id), '[]'::jsonb),
    'achievements', coalesce((select jsonb_agg(jsonb_build_object('code', a.code, 'level', a.level, 'earned_at', a.earned_at, 'shared_at', a.shared_at) order by a.earned_at)
      from achievements a, me where a.user_id = me.id), '[]'::jsonb),
    'content_removed', coalesce((select jsonb_agg(jsonb_build_object('content_kind', m.content_kind, 'reason', m.reason, 'removed_at', m.removed_at,
        'appeal_text', m.appeal_text, 'appealed_at', m.appealed_at, 'decision', m.decision) order by m.removed_at)
      from moderation_removals m, me where m.owner_id = me.id), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('about', r.target_type, 'reason', r.reason, 'status', r.status, 'created_at', r.created_at))
      from reports r, me where r.reporter_id = me.id), '[]'::jsonb)
  );
$$;
