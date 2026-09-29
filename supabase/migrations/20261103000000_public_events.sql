-- Public events. When creating an event you choose:
-- - "Con invitación" (as until now): only the creator and the invited people see it;
-- - "Público": the creator's friends and friends of friends see it too, and can
--   sign up directly ("Voy" / "Quizá") without an invitation.
-- Inicio lists the upcoming public events you can see and have not joined yet.
-- Blocks apply: nobody sees public events of people they blocked or who blocked them.
-- Who is invited: people who only see a public event (not invited, not joined)
-- see only who is going or may go, never who was invited and did not answer or
-- said no, and never anyone they have a block with.

alter table events add column is_public boolean not null default false;

create or replace function can_see_event(me uuid, target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from events e
    where e.id = target
      and (
        e.creator_id = me
        or is_event_member(e.id, me)
        or (
          e.is_public
          and not is_blocked_between(me, e.creator_id)
          and (are_friends(me, e.creator_id) or mutual_friends(me, e.creator_id) > 0)
        )
      )
  );
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
    'is_public', e.is_public,
    'created_at', e.created_at,
    'updated_at', e.updated_at,
    'creator', person_summary(e.creator_id),
    'is_creator', e.creator_id = me,
    'my_status', (select m.status from event_members m where m.event_id = e.id and m.user_id = me),
    'counts', jsonb_build_object(
      'going', (select count(*) from event_members m where m.event_id = e.id and m.status = 'going'),
      'maybe', (select count(*) from event_members m where m.event_id = e.id and m.status = 'maybe'),
      'declined', case when inside then (select count(*) from event_members m where m.event_id = e.id and m.status = 'declined') else 0 end,
      'pending', case when inside then (select count(*) from event_members m where m.event_id = e.id and m.status = 'pending') else 0 end
    ),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(m.user_id), 'status', m.status)
        order by case m.status when 'going' then 0 when 'maybe' then 1 when 'pending' then 2 else 3 end)
      from event_members m
      where m.event_id = e.id
        and (inside or m.status in ('going', 'maybe'))
        and (m.user_id = me or not is_blocked_between(me, m.user_id))
    ), '[]'::jsonb)
  )
  from events e, lateral (select e.creator_id = me or is_event_member(e.id, me) as inside) x
  where e.id = target;
$$;

drop function if exists create_event(text, text, text, date, time, text, uuid[]);

create or replace function create_event(
  title text, description text, image_path text, event_date date, event_time time, location text,
  invitees uuid[] default '{}', is_public boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  perform yg_check_event(title, description, location);
  perform yg_check_own_path(me, image_path);
  insert into events (creator_id, title, description, image_path, date, time, location, is_public)
  values (me, trim(title), trim(coalesce(description, '')), image_path, event_date, event_time, trim(location), coalesce(create_event.is_public, false))
  returning id into new_id;
  insert into event_members (event_id, user_id, status, invited_by, responded_at) values (new_id, me, 'going', me, now());
  perform yg_invite_to_event(me, new_id, invitees);
  return event_json(me, new_id);
end;
$$;

drop function if exists update_event(uuid, text, text, text, date, time, text);

-- Returns { event, removed_path }: the previous image when it was replaced or removed.
create or replace function update_event(
  target uuid, title text, description text, image_path text, event_date date, event_time time, location text,
  is_public boolean default false
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
    is_public = coalesce(update_event.is_public, false),
    updated_at = now()
  where id = target;
  return jsonb_build_object(
    'event', event_json(me, target),
    'removed_path', case when ev.image_path is distinct from image_path then ev.image_path end
  );
end;
$$;

-- Invited people answer; in a public event anyone who can see it joins by answering.
create or replace function respond_event(target uuid, answer rsvp_status) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  ev events;
begin
  if answer = 'pending' then raise exception 'yg:validation:Respuesta no válida.'; end if;
  select * into ev from events where id = target;
  if ev.id is null then raise exception 'yg:not_found:Este evento ya no existe.'; end if;
  update event_members set status = answer, responded_at = now() where event_id = target and user_id = me;
  if not found then
    if not (ev.is_public and can_see_event(me, target)) then
      raise exception 'yg:forbidden:No estás invitado a este evento.';
    end if;
    insert into event_members (event_id, user_id, status, invited_by, responded_at) values (target, me, answer, me, now());
  end if;
  return event_json(me, target);
end;
$$;

-- Upcoming public events you can see and have not joined or been invited to,
-- the soonest first.
create or replace function public_events(max_results int default 100) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id),
  found as (
    select e.id, e.date, e.time
    from events e, me
    where e.is_public
      and e.date >= current_date
      and e.creator_id <> me.id
      and not is_event_member(e.id, me.id)
      and can_see_event(me.id, e.id)
    order by e.date, e.time
    limit least(max_results, 100)
  )
  select coalesce(jsonb_agg(event_json((select id from me), f.id) order by f.date, f.time), '[]'::jsonb) from found f;
$$;

-- Event images follow who can see the event.
create or replace function yg_can_read_photo_file(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select split_part(path, '/', 1) = auth.uid()::text
    or exists (select 1 from photos ph where ph.storage_path = path and can_view_photo(auth.uid(), ph.id))
    or exists (select 1 from events e where e.image_path = path and can_see_event(auth.uid(), e.id))
    or (is_moderator() and exists (select 1 from reports r where r.snapshot ->> 'storage_path' = path));
$$;

grant execute on function create_event(text, text, text, date, time, text, uuid[], boolean) to authenticated;
grant execute on function update_event(uuid, text, text, text, date, time, text, boolean) to authenticated;
grant execute on function public_events(int) to authenticated;

-- Search also finds the public events you can see.
create or replace function global_search(q text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := yg_me();
  pattern text := '%' || yg_fold(trim(coalesce(q, ''))) || '%';
begin
  if length(trim(coalesce(q, ''))) = 0 then
    return jsonb_build_object('people', '[]'::jsonb, 'events', '[]'::jsonb, 'albums', '[]'::jsonb);
  end if;
  perform yg_rate_limit('search', 40);
  return jsonb_build_object(
    'people', yg_search_people(me, q, 12),
    'events', coalesce((
      select jsonb_agg(event_json(me, e.id) order by e.date desc)
      from (
        select e.id, e.date from events e
        where can_see_event(me, e.id)
          and yg_fold(e.title || ' ' || e.location || ' ' || e.description) like pattern
        order by e.date desc limit 8
      ) e
    ), '[]'::jsonb),
    'albums', coalesce((
      select jsonb_agg(album_json(me, a.id) order by a.updated_at desc)
      from (
        select a.id, a.updated_at from albums a
        where a.kind = 'user' and can_view_profile(me, a.owner_id)
          and yg_fold(a.title || ' ' || a.description) like pattern
        order by a.updated_at desc limit 8
      ) a
    ), '[]'::jsonb)
  );
end;
$$;
