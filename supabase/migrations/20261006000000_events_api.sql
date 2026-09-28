-- Events ("planes"): only the creator and the invited people see them. The
-- image lives in the private "photos" bucket and only they can read it.

alter table events add column image_path text;

create policy "read event images" on storage.objects for select to authenticated
  using (
    bucket_id = 'photos'
    and exists (
      select 1 from events e
      where e.image_path = name and (e.creator_id = auth.uid() or is_event_member(e.id, auth.uid()))
    )
  );

create or replace function can_see_event(me uuid, target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from events e where e.id = target and (e.creator_id = me or is_event_member(e.id, me)));
$$;

create or replace function event_json(me uuid, target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', e.id,
    'creator_id', e.creator_id,
    'title', e.title,
    'description', e.description,
    'image_path', e.image_path,
    'date', e.date,
    'time', to_char(e.time, 'HH24:MI'),
    'location', e.location,
    'created_at', e.created_at,
    'updated_at', e.updated_at,
    'creator', person_summary(e.creator_id),
    'is_creator', e.creator_id = me,
    'my_status', (select m.status from event_members m where m.event_id = e.id and m.user_id = me),
    'counts', jsonb_build_object(
      'going', (select count(*) from event_members m where m.event_id = e.id and m.status = 'going'),
      'maybe', (select count(*) from event_members m where m.event_id = e.id and m.status = 'maybe'),
      'declined', (select count(*) from event_members m where m.event_id = e.id and m.status = 'declined'),
      'pending', (select count(*) from event_members m where m.event_id = e.id and m.status = 'pending')
    ),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(m.user_id), 'status', m.status)
        order by case m.status when 'going' then 0 when 'maybe' then 1 when 'pending' then 2 else 3 end)
      from event_members m where m.event_id = e.id
    ), '[]'::jsonb)
  )
  from events e where e.id = target;
$$;

create or replace function yg_check_event(title text, description text, location text) returns void
language plpgsql immutable as $$
begin
  if char_length(trim(coalesce(title, ''))) = 0 then raise exception 'yg:validation:El título es obligatorio.'; end if;
  if char_length(trim(title)) > 80 then raise exception 'yg:validation:El título no puede superar los 80 caracteres.'; end if;
  if char_length(trim(coalesce(description, ''))) > 1500 then raise exception 'yg:validation:La descripción no puede superar los 1500 caracteres.'; end if;
  if char_length(trim(coalesce(location, ''))) = 0 then raise exception 'yg:validation:La ubicación es obligatoria.'; end if;
  if char_length(trim(location)) > 120 then raise exception 'yg:validation:La ubicación no puede superar los 120 caracteres.'; end if;
end;
$$;

-- An image path must be in the caller's own folder.
create or replace function yg_check_own_path(me uuid, path text) returns void
language plpgsql immutable as $$
begin
  if path is not null and split_part(path, '/', 1) <> me::text then
    raise exception 'yg:forbidden:No puedes usar esa imagen.';
  end if;
end;
$$;

-- Invites friends who are not invited yet; returns how many were new.
create or replace function yg_invite_to_event(me uuid, target uuid, people uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare
  person uuid;
  fresh int := 0;
begin
  foreach person in array (select array(select distinct unnest(coalesce(people, '{}')))) loop
    continue when exists (select 1 from event_members where event_id = target and user_id = person);
    if not are_friends(me, person) then raise exception 'yg:forbidden:Solo puedes invitar a tus amigos.'; end if;
    insert into event_members (event_id, user_id, status, invited_by) values (target, person, 'pending', me);
    fresh := fresh + 1;
  end loop;
  return fresh;
end;
$$;

-- Every event you created or were invited to; the app splits them into
-- invitations, upcoming and past.
create or replace function list_events() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(event_json(yg_me(), e.id) order by e.date, e.time), '[]'::jsonb)
  from events e
  where e.creator_id = yg_me() or is_event_member(e.id, yg_me());
$$;

create or replace function get_event(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not exists (select 1 from events where id = target) then raise exception 'yg:not_found:Este evento ya no existe.'; end if;
  if not can_see_event(me, target) then raise exception 'yg:forbidden:No estás invitado a este evento.'; end if;
  return event_json(me, target);
end;
$$;

create or replace function create_event(
  title text, description text, image_path text, event_date date, event_time time, location text, invitees uuid[] default '{}'
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  perform yg_check_event(title, description, location);
  perform yg_check_own_path(me, image_path);
  insert into events (creator_id, title, description, image_path, date, time, location)
  values (me, trim(title), trim(coalesce(description, '')), image_path, event_date, event_time, trim(location))
  returning id into new_id;
  insert into event_members (event_id, user_id, status, invited_by, responded_at) values (new_id, me, 'going', me, now());
  perform yg_invite_to_event(me, new_id, invitees);
  return event_json(me, new_id);
end;
$$;

-- Returns { event, removed_path }: the previous image when it was replaced or removed.
create or replace function update_event(
  target uuid, title text, description text, image_path text, event_date date, event_time time, location text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  ev events;
begin
  select * into ev from events where id = target;
  if ev.id is null then raise exception 'yg:not_found:Este evento ya no existe.'; end if;
  if ev.creator_id <> me then raise exception 'yg:forbidden:Solo quien crea el evento puede editarlo.'; end if;
  perform yg_check_event(title, description, location);
  if image_path is distinct from ev.image_path then perform yg_check_own_path(me, image_path); end if;
  update events set
    title = trim(update_event.title),
    description = trim(coalesce(update_event.description, '')),
    image_path = update_event.image_path,
    date = event_date,
    time = event_time,
    location = trim(update_event.location),
    updated_at = now()
  where id = target;
  return jsonb_build_object(
    'event', event_json(me, target),
    'removed_path', case when ev.image_path is distinct from image_path then ev.image_path end
  );
end;
$$;

-- Returns the image path so the app deletes the file.
create or replace function delete_event(target uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  ev events;
begin
  select * into ev from events where id = target;
  if ev.id is null then raise exception 'yg:not_found:Este evento ya no existe.'; end if;
  if ev.creator_id <> me then raise exception 'yg:forbidden:Solo quien crea el evento puede eliminarlo.'; end if;
  delete from notifications where type = 'event_invite' and target_id = target;
  delete from events where id = target;
  return ev.image_path;
end;
$$;

-- The creator and anyone attending can invite their friends.
create or replace function invite_to_event(target uuid, people uuid[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  mine rsvp_status;
  ev events;
  invited int;
begin
  select * into ev from events where id = target;
  if ev.id is null then raise exception 'yg:not_found:Este evento ya no existe.'; end if;
  if not can_see_event(me, target) then raise exception 'yg:forbidden:No estás invitado a este evento.'; end if;
  if coalesce(array_length(people, 1), 0) = 0 then raise exception 'yg:validation:Elige al menos a una persona.'; end if;
  select status into mine from event_members where event_id = target and user_id = me;
  if ev.creator_id <> me and coalesce(mine::text, '') not in ('going', 'maybe') then
    raise exception 'yg:forbidden:No puedes invitar a este evento.';
  end if;
  invited := yg_invite_to_event(me, target, people);
  return jsonb_build_object('event', event_json(me, target), 'invited', invited);
end;
$$;

create or replace function respond_event(target uuid, answer rsvp_status) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if answer = 'pending' then raise exception 'yg:validation:Respuesta no válida.'; end if;
  if not exists (select 1 from events where id = target) then raise exception 'yg:not_found:Este evento ya no existe.'; end if;
  update event_members set status = answer, responded_at = now() where event_id = target and user_id = me;
  if not found then raise exception 'yg:forbidden:No estás invitado a este evento.'; end if;
  return event_json(me, target);
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'can_see_event(uuid, uuid)', 'event_json(uuid, uuid)', 'yg_invite_to_event(uuid, uuid, uuid[])',
    'list_events()', 'get_event(uuid)', 'create_event(text, text, text, date, time, text, uuid[])',
    'update_event(uuid, text, text, text, date, time, text)', 'delete_event(uuid)',
    'invite_to_event(uuid, uuid[])', 'respond_event(uuid, rsvp_status)'
  ] loop
    execute format('revoke execute on function %s from public', fn);
    execute format('revoke execute on function %s from anon', fn);
  end loop;
  foreach fn in array array[
    'list_events()', 'get_event(uuid)', 'create_event(text, text, text, date, time, text, uuid[])',
    'update_event(uuid, text, text, text, date, time, text)', 'delete_event(uuid)',
    'invite_to_event(uuid, uuid[])', 'respond_event(uuid, rsvp_status)'
  ] loop
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;
