-- Rate limits (audit R14): each person can only do so many writes and searches
-- per minute, against spam and bulk extraction of profiles. Counted per person
-- and minute; old counters are cleaned up as new ones come in. The limits are
-- technical defaults: adjust them in yg_rate_limit's callers if needed.

create table rate_limits (
  user_id      uuid not null references profiles (id) on delete cascade,
  action       text not null,
  window_start timestamptz not null,
  hits         int not null default 0,
  primary key (user_id, action, window_start)
);
alter table rate_limits enable row level security;
revoke all on table rate_limits from authenticated, anon;

create or replace function yg_rate_limit(what text, max_per_minute int) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  total int;
begin
  -- System work (triggers, SQL editor) is not limited.
  if me is null then return; end if;
  insert into rate_limits (user_id, action, window_start, hits)
  values (me, what, date_trunc('minute', now()), 1)
  on conflict (user_id, action, window_start) do update set hits = rate_limits.hits + 1
  returning hits into total;
  if total > max_per_minute then
    raise exception 'yg:rate_limited:Vas demasiado rápido. Espera un minuto e inténtalo de nuevo.';
  end if;
  -- Occasional clean-up of past windows.
  if random() < 0.02 then
    delete from rate_limits where window_start < now() - interval '1 hour';
  end if;
end;
$$;

-- ---- Writes: a trigger per table, whatever function made the insert ------------------

create or replace function on_rate_limited_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform yg_rate_limit(tg_argv[0], tg_argv[1]::int);
  return new;
end;
$$;

create trigger rate_limit_messages before insert on messages for each row execute function on_rate_limited_insert('message', '30');
create trigger rate_limit_comments before insert on comments for each row execute function on_rate_limited_insert('comment', '20');
create trigger rate_limit_wall before insert on wall_messages for each row execute function on_rate_limited_insert('wall_message', '10');
create trigger rate_limit_reports before insert on reports for each row execute function on_rate_limited_insert('report', '10');
create trigger rate_limit_friend_requests before insert on friend_requests for each row execute function on_rate_limited_insert('friend_request', '20');
create trigger rate_limit_invitations before insert on invitations for each row execute function on_rate_limited_insert('invitation', '10');
create trigger rate_limit_statuses before insert on posts for each row execute function on_rate_limited_insert('post', '10');
create trigger rate_limit_photos before insert on photos for each row execute function on_rate_limited_insert('photo', '60');
create trigger rate_limit_events before insert on events for each row execute function on_rate_limited_insert('event', '10');

-- ---- Searches -------------------------------------------------------------------------

-- The search itself, shared by both RPCs below (not in the API).
create or replace function yg_search_people(me uuid, q text, max_results int) returns jsonb
language sql stable security definer set search_path = public as $$
  with found as (
    select p.id, mutual_friends(me, p.id) as mutual
    from profiles p
    where p.id <> me
      and not p.needs_setup
      and not is_blocked_between(me, p.id)
      and length(trim(q)) > 0
      and yg_fold(p.first_name || ' ' || p.last_name || ' ' || case when can_view_city(me, p.id) then p.city else '' end)
          like '%' || yg_fold(trim(q)) || '%'
    order by mutual desc, p.first_name
    limit least(max_results, 50)
  )
  select people_view(coalesce(array_agg(id), '{}')) from found;
$$;

create or replace function search_people(q text, max_results int default 30) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_rate_limit('search', 40);
  return yg_search_people(me, q, max_results);
end;
$$;

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
        where (e.creator_id = me or is_event_member(e.id, me))
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
