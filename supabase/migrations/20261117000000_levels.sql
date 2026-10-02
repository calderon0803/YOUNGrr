-- Experience (XP) and levels.
--
-- - Experience once earned is never lost, and nothing can be farmed:
--   - what you publish (photos, comments on other people's things, messages on
--     other people's walls, the Gallinero, tastes) and the Grr you receive only
--     count if they still exist 7 days later: a nightly job turns them into
--     experience then. Publishing and deleting gives nothing;
--   - each thing counts once (a Grr taken back and given again, a friendship
--     undone and made again, or a film removed and added again never count twice);
--   - low daily limits, by the day it was published;
--   - statuses give nothing (each one replaces the previous).
-- - At once: logging in each day (with a bonus at 7 and 30 days in a row),
--   completing the profile, invitations that end in a sign up and achievements.
-- - Levels only show recognition: the number, seen by whoever can see your
--   profile; your exact progress only by you. Their titles are achievements
--   (nivel_5…), which give no experience themselves. No ranking.
-- The amounts and limits are in yg_xp_candidates() and yg_award_instant(); the
-- app explains them (src/config/levels.js).

create table xp_ledger (
  user_id   uuid not null references profiles (id) on delete cascade,
  source    text not null check (source in ('photo', 'comment', 'wall', 'gallinero', 'taste', 'grr', 'friend', 'profile', 'invite', 'achievement', 'login', 'streak')),
  -- What gave it: each one only once.
  ref       text not null,
  amount    int not null check (amount > 0),
  day       date not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, source, ref)
);
create index xp_ledger_window on xp_ledger (user_id, source, day);

create table xp_totals (
  user_id    uuid primary key references profiles (id) on delete cascade,
  xp         int not null default 0,
  level      int not null default 1,
  -- The last level you were told about.
  level_seen int not null default 1,
  updated_at timestamptz not null default now()
);

-- Days you came in, for the streak (the last two months are enough).
create table xp_logins (
  user_id uuid not null references profiles (id) on delete cascade,
  day     date not null,
  primary key (user_id, day)
);

alter table xp_ledger enable row level security;
alter table xp_totals enable row level security;
alter table xp_logins enable row level security;
revoke all on table xp_ledger, xp_totals, xp_logins from authenticated, anon;

insert into app_settings (key, value) values ('xp_matured_until', null) on conflict (key) do nothing;

-- ---- Levels ----------------------------------------------------------------------------------------

-- Experience needed to reach a level: 0, 50, 141, 260, 400… (each costs a bit more).
create or replace function yg_xp_for_level(n int) returns int
language sql immutable as $$
  select case when n <= 1 then 0 else round(50 * power(n - 1, 1.5))::int end;
$$;

create or replace function yg_level_for_xp(total int) returns int
language sql immutable as $$
  select coalesce(max(n), 1) from generate_series(1, 500) n where yg_xp_for_level(n) <= total;
$$;

-- ---- What you publish and receive: it counts 7 days later -------------------------------------------

-- What would give experience between two days, not counted yet, within the
-- daily limits (a week for friendships).
create or replace function yg_xp_candidates(person uuid, d1 date, d2 date) returns table (src text, ref_id text, points int, on_day date)
language sql stable security definer set search_path = public as $$
  with raw as (
    select 'photo' as s, ph.id::text as r, 2 as a, ph.created_at as at from photos ph where ph.owner_id = person
    union all
    select 'comment', c.id::text, 1, c.created_at from comments c
      left join posts p on p.id = c.post_id left join photos ph on ph.id = c.photo_id
      where c.author_id = person and coalesce(p.author_id, ph.owner_id) <> person
    union all
    select 'wall', w.id::text, 1, w.created_at from wall_messages w where w.author_id = person and w.profile_id <> person
    union all
    select 'gallinero', gp.id::text, 1, gp.created_at from group_posts gp where gp.author_id = person
    union all
    select 'gallinero', gr.id::text, 1, gr.created_at from group_replies gr where gr.author_id = person
    union all
    select 'taste', t.kind || ':' || t.source || ':' || t.external_id, 1, t.created_at from tastes t where t.user_id = person
    union all
    select 'grr', g.user_id::text || ':' || coalesce(g.post_id, g.photo_id)::text, 1, g.created_at from grrs g
      left join posts p on p.id = g.post_id left join photos ph on ph.id = g.photo_id
      where g.user_id <> person and coalesce(p.author_id, ph.owner_id) = person
    union all
    select 'grr', gg.user_id::text || ':' || gg.post_id::text, 1, gg.created_at from group_post_grrs gg
      join group_posts gp on gp.id = gg.post_id
      where gp.author_id = person and gg.user_id <> person
    union all
    select 'friend', (case when f.user_a = person then f.user_b else f.user_a end)::text, 5, f.created_at from friendships f
      where person in (f.user_a, f.user_b)
  ),
  fresh as (
    select raw.*, yg_local_day(raw.at) as d,
           case when raw.s = 'friend' then date_trunc('week', yg_local_day(raw.at))::date else yg_local_day(raw.at) end as w
    from raw
    where yg_local_day(raw.at) between d1 and d2
      and not exists (select 1 from xp_ledger l where l.user_id = person and l.source = raw.s and l.ref = raw.r)
  ),
  ranked as (
    select f.*,
           row_number() over (partition by f.s, f.w order by f.at, f.r) as n,
           -- What that same day (or week) already gave counts against the limit.
           (select count(*) from xp_ledger l
            where l.user_id = person and l.source = f.s
              and case when f.s = 'friend' then date_trunc('week', l.day)::date = f.w else l.day = f.w end) as used
    from fresh f
  )
  select s, r, a, d from ranked
  where n + used <= case s when 'photo' then 10 when 'comment' then 10 when 'wall' then 5 when 'gallinero' then 10
                           when 'taste' then 10 when 'grr' then 20 when 'friend' then 5 else 0 end;
$$;

-- ---- What is given at once -----------------------------------------------------------------------------

create or replace function yg_award_instant(person uuid) returns void
language sql volatile security definer set search_path = public as $$
  -- Completing the profile: picture, presentation and town.
  insert into xp_ledger (user_id, source, ref, amount, day)
  select person, 'profile', 'profile', 20, yg_local_day(now()) from profiles p
  where p.id = person and p.avatar_url is not null and coalesce(p.bio, '') <> '' and coalesce(p.city, '') <> ''
  on conflict do nothing;
  -- Each person who signed up with your invitation.
  insert into xp_ledger (user_id, source, ref, amount, day)
  select person, 'invite', i.used_by::text, 25, yg_local_day(coalesce(i.used_at, now())) from invitations i
  where i.inviter_id = person and i.used_by is not null
  on conflict do nothing;
  -- Each level of each achievement (the level titles give nothing).
  insert into xp_ledger (user_id, source, ref, amount, day)
  select person, 'achievement', a.code || ':' || t,
         case when cardinality(d.thresholds) > 1 then (array[10, 20, 30, 50])[t] else 20 end,
         yg_local_day(a.earned_at)
  from achievements a
  join yg_achievement_defs() d on d.code = a.code
  cross join lateral generate_series(1, a.level) t
  where a.user_id = person and a.code not like 'nivel\_%'
  on conflict do nothing;
$$;

-- Adds up the experience, sets the level and awards the level achievements.
create or replace function yg_xp_refresh(person uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  total int;
  before int;
  now_level int;
begin
  if not exists (select 1 from profiles where id = person and not needs_setup) then return; end if;
  perform yg_check_achievements(person);
  perform yg_award_instant(person);
  select coalesce(sum(amount), 0) into total from xp_ledger where user_id = person;
  now_level := yg_level_for_xp(total);
  select level into before from xp_totals where user_id = person;
  -- A first total (the start of the system) is not announced.
  insert into xp_totals (user_id, xp, level, level_seen) values (person, total, now_level, now_level)
  on conflict (user_id) do update set xp = excluded.xp, level = excluded.level, updated_at = now();
  if before is distinct from now_level then perform yg_check_achievements(person); end if;
end;
$$;

-- Every night: what was published 7 days ago (and is still there) becomes
-- experience. The first run counts everything from before.
create or replace function yg_mature_xp() returns int
language plpgsql volatile security definer set search_path = public as $$
declare
  until_day date := yg_local_day(now()) - 7;
  from_day date := coalesce((select value::date + 1 from app_settings where key = 'xp_matured_until'), date '2000-01-01');
  person uuid;
  n int := 0;
begin
  for person in select id from profiles where not needs_setup loop
    if from_day <= until_day then
      insert into xp_ledger (user_id, source, ref, amount, day)
      select person, c.src, c.ref_id, c.points, c.on_day from yg_xp_candidates(person, from_day, until_day) c
      on conflict do nothing;
    end if;
    perform yg_xp_refresh(person);
    n := n + 1;
  end loop;
  if from_day <= until_day then
    update app_settings set value = until_day::text where key = 'xp_matured_until';
  end if;
  delete from xp_logins where day < yg_local_day(now()) - 60;
  return n;
end;
$$;
revoke execute on function yg_mature_xp() from public, anon, authenticated;

-- ---- The API -------------------------------------------------------------------------------------------

create or replace function yg_streak(person uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from (
    select l.day, row_number() over (order by l.day desc) as rn from xp_logins l
    where l.user_id = person and l.day <= yg_local_day(now())
  ) x
  where x.day = yg_local_day(now()) - (x.rn - 1)::int;
$$;

-- Your experience: the level, what you have, what the next level needs and
-- what is on its way (published in the last days, still within the limits).
create or replace function my_xp() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := yg_me();
  t xp_totals;
  pending_from date := coalesce((select value::date + 1 from app_settings where key = 'xp_matured_until'), yg_local_day(now()) - 6);
begin
  perform yg_xp_refresh(me);
  select * into t from xp_totals where user_id = me;
  return jsonb_build_object(
    'xp', coalesce(t.xp, 0),
    'level', coalesce(t.level, 1),
    'level_xp', yg_xp_for_level(coalesce(t.level, 1)),
    'next_level_xp', yg_xp_for_level(coalesce(t.level, 1) + 1),
    'pending', (select coalesce(sum(points), 0) from yg_xp_candidates(me, pending_from, yg_local_day(now()))),
    'streak', yg_streak(me)
  );
end;
$$;

-- Coming in: once a day it gives experience, and a bonus at 7 and 30 days in a row.
create or replace function record_daily_visit() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := yg_me();
  today date := yg_local_day(now());
  days int;
begin
  insert into xp_logins (user_id, day) values (me, today) on conflict do nothing;
  if found then
    insert into xp_ledger (user_id, source, ref, amount, day) values (me, 'login', today::text, 1, today) on conflict do nothing;
    days := yg_streak(me);
    if days = 7 then
      insert into xp_ledger (user_id, source, ref, amount, day) values (me, 'streak', '7:' || today, 5, today) on conflict do nothing;
    elsif days = 30 then
      insert into xp_ledger (user_id, source, ref, amount, day) values (me, 'streak', '30:' || today, 20, today) on conflict do nothing;
    end if;
  end if;
  return my_xp();
end;
$$;

-- Someone's level, for whoever can see their profile.
create or replace function user_level(target uuid) returns int
language sql stable security definer set search_path = public as $$
  select case when can_view_profile(yg_me(), target) then coalesce((select level from xp_totals where user_id = target), 1) end;
$$;

create or replace function mark_level_seen() returns void
language sql volatile security definer set search_path = public as $$
  update xp_totals set level_seen = level where user_id = yg_me();
$$;

grant execute on function my_xp() to authenticated;
grant execute on function record_daily_visit() to authenticated;
grant execute on function user_level(uuid) to authenticated;
grant execute on function mark_level_seen() to authenticated;

-- ---- Level titles are achievements ----------------------------------------------------------------------

create or replace function yg_achievement_defs() returns table (code text, thresholds int[])
language sql immutable as $$
  values
    ('fundador', array[1]),
    ('primeros_pasos', array[1]),
    ('estreno', array[1]),
    ('anfitrion', array[1, 2, 3, 5]),
    ('cuadrilla', array[5, 15, 30, 50]),
    ('organizador', array[1, 5, 15, 30]),
    ('fomo', array[3, 10, 25, 50]),
    ('planazo', array[1]),
    ('fotografo', array[10, 50, 200, 500]),
    ('album_oro', array[1]),
    ('paparazzi', array[10]),
    ('grrrr', array[10, 50, 200, 500]),
    ('buen_rollo', array[10]),
    -- Level titles (src/config/achievements.js).
    ('nivel_5', array[5]),
    ('nivel_10', array[10]),
    ('nivel_20', array[20]),
    ('nivel_30', array[30]),
    ('nivel_50', array[50])
$$;

create or replace function yg_achievement_metric(person uuid, what text) returns int
language sql stable security definer set search_path = public as $$
  select case what
    when 'fundador' then (
      select case when p.created_at < coalesce((select value::timestamptz from app_settings where key = 'founders_until'), 'infinity') then 1 else 0 end
      from profiles p where p.id = person)
    when 'primeros_pasos' then (
      select case when p.avatar_url is not null and not p.needs_setup then 1 else 0 end from profiles p where p.id = person)
    -- Photos uploaded (the profile picture is not one of them).
    when 'estreno' then (select count(*)::int from photos where owner_id = person)
    when 'fotografo' then (select count(*)::int from photos where owner_id = person)
    when 'anfitrion' then (select count(*)::int from invitations where inviter_id = person and used_by is not null)
    when 'cuadrilla' then (select count(*)::int from friendships where person in (user_a, user_b))
    -- Past events you created where at least 3 people went.
    when 'organizador' then (
      select count(*)::int from events e
      where e.creator_id = person and e.date < current_date
        and (select count(*) from event_members m where m.event_id = e.id and m.status = 'going') >= 3)
    -- Past events of other people you went to.
    when 'fomo' then (
      select count(*)::int from event_members m join events e on e.id = m.event_id
      where m.user_id = person and m.status = 'going' and e.creator_id <> person and e.date < current_date)
    when 'planazo' then (
      select case when exists (
        select 1 from events e
        where e.creator_id = person
          and (select count(*) from event_members m where m.event_id = e.id and m.status = 'going') >= 10
      ) then 1 else 0 end)
    when 'album_oro' then (
      select case when exists (
        select 1 from albums a
        where a.owner_id = person and a.kind = 'user'
          and (select count(*) from album_photos ap where ap.album_id = a.id) >= 20
      ) then 1 else 0 end)
    when 'paparazzi' then (select count(distinct user_id)::int from photo_tags where tagged_by = person and user_id <> person)
    -- Grr from other people on your statuses and photos.
    when 'grrrr' then (
      select count(*)::int from grrs g
      where g.user_id <> person
        and (g.post_id in (select id from posts where author_id = person and kind = 'status')
             or g.photo_id in (select id from photos where owner_id = person)))
    when 'buen_rollo' then (select count(distinct profile_id)::int from wall_messages where author_id = person and profile_id <> person)
    when 'nivel_5' then (select level from xp_totals where user_id = person)
    when 'nivel_10' then (select level from xp_totals where user_id = person)
    when 'nivel_20' then (select level from xp_totals where user_id = person)
    when 'nivel_30' then (select level from xp_totals where user_id = person)
    when 'nivel_50' then (select level from xp_totals where user_id = person)
    else 0
  end;
$$;

-- ---- Counters in Inicio: "Has subido al nivel N" -----------------------------------------------------

create or replace function notification_state() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select jsonb_build_object(
    'settings', (select to_jsonb(s) from user_settings s where s.user_id = me.id),
    'conversation_ids', coalesce((
      select jsonb_agg(cm.conversation_id) from conversation_members cm
      where cm.user_id = me.id and yg_unread_in(me.id, cm.conversation_id) > 0
    ), '[]'::jsonb),
    'request_count', (select count(*) from friend_requests r where r.to_id = me.id and r.status = 'pending'),
    'invitation_event_ids', coalesce((
      select jsonb_agg(m.event_id) from event_members m where m.user_id = me.id and m.status = 'pending'
    ), '[]'::jsonb),
    'share_photo_ids', coalesce((
      select jsonb_agg(o.photo_id) from photo_owners o where o.user_id = me.id and o.status = 'pending'
    ), '[]'::jsonb),
    'group_invite_ids', coalesce((
      select jsonb_agg(i.group_id) from group_invites i where i.user_id = me.id and not is_blocked_between(me.id, i.invited_by)
    ), '[]'::jsonb),
    'group_request_ids', coalesce((
      select jsonb_agg(r.group_id) from group_join_requests r
      where yg_is_group_admin(r.group_id, me.id) and not is_blocked_between(me.id, r.user_id)
    ), '[]'::jsonb),
    'group_notice_count', (select count(*) from group_notices n where n.user_id = me.id),
    -- One entry per mention, with its group.
    'group_mention_ids', coalesce((
      select jsonb_agg(x.group_id) from (
        select m.group_id, generate_series(1, yg_group_mentions(me.id, m.group_id)) as n
        from group_members m where m.user_id = me.id and yg_group_notify(m.group_id, me.id) <> 'none'
      ) x
    ), '[]'::jsonb),
    'chat_invite_ids', coalesce((
      select jsonb_agg(ci.conversation_id) from conversation_invites ci
      where ci.user_id = me.id and not is_blocked_between(me.id, ci.invited_by)
    ), '[]'::jsonb),
    -- A level you have not been told about yet.
    'level_up', (select t.level from xp_totals t where t.user_id = me.id and t.level > t.level_seen),
    'unread', coalesce((
      select jsonb_agg(jsonb_build_object('type', n.type, 'target_id', n.target_id) order by n.created_at desc)
      from notifications n where n.user_id = me.id and n.read_at is null
    ), '[]'::jsonb)
  )
  from me;
$$;

-- ---- Data export: your experience --------------------------------------------------------------------

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
    'groups', coalesce((select jsonb_agg(jsonb_build_object('name', g.name, 'privacy', g.privacy, 'role', gm.role, 'joined_at', gm.joined_at,
        'profile_share', gm.profile_share, 'notify', gm.notify, 'hidden', gm.hidden) order by gm.joined_at)
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
    'chat_invitations_received', coalesce((select jsonb_agg(jsonb_build_object('chat', c.title, 'created_at', ci.created_at))
      from conversation_invites ci join conversations c on c.id = ci.conversation_id, me where ci.user_id = me.id), '[]'::jsonb),
    'tastes', coalesce((select jsonb_agg(jsonb_build_object('kind', t.kind, 'title', t.title, 'year', t.year, 'source', t.source,
        'external_id', t.external_id, 'stars', t.rating, 'created_at', t.created_at) order by t.kind, t.created_at)
      from tastes t, me where t.user_id = me.id), '[]'::jsonb),
    'experience', (select jsonb_build_object('xp', t.xp, 'level', t.level, 'updated_at', t.updated_at) from xp_totals t, me where t.user_id = me.id),
    'experience_by_source', coalesce((select jsonb_agg(jsonb_build_object('source', x.source, 'xp', x.xp, 'times', x.n) order by x.source)
      from (select l.source, sum(l.amount) as xp, count(*) as n from xp_ledger l, me where l.user_id = me.id group by l.source) x), '[]'::jsonb),
    'login_days', coalesce((select jsonb_agg(l.day order by l.day) from xp_logins l, me where l.user_id = me.id), '[]'::jsonb),
    'invitations_sent', coalesce((select jsonb_agg(jsonb_build_object('email', i.email, 'created_at', i.created_at, 'expires_at', i.expires_at, 'used', i.used_by is not null))
      from invitations i, me where i.inviter_id = me.id), '[]'::jsonb),
    'achievements', coalesce((select jsonb_agg(jsonb_build_object('code', a.code, 'level', a.level, 'earned_at', a.earned_at, 'shared_at', a.shared_at) order by a.earned_at)
      from achievements a, me where a.user_id = me.id), '[]'::jsonb),
    'content_removed', coalesce((select jsonb_agg(jsonb_build_object('content_kind', m.content_kind, 'reason', m.reason, 'rule', m.rule, 'removed_at', m.removed_at,
        'appeal_text', m.appeal_text, 'appealed_at', m.appealed_at, 'decision', m.decision) order by m.removed_at)
      from moderation_removals m, me where m.owner_id = me.id), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('about', r.target_type, 'reason', r.reason, 'illegal', r.illegal, 'illegal_category', r.illegal_category, 'details', r.details, 'status', r.status, 'created_at', r.created_at))
      from reports r, me where r.reporter_id = me.id), '[]'::jsonb)
  );
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('youngrr-xp', '40 3 * * *', 'select public.yg_mature_xp()');
  end if;
exception when others then
  raise notice 'pg_cron no disponible: programa yg_mature_xp() a mano (%).', sqlerrm;
end;
$$;

-- Everyone gets the experience of what they already did (with the same rules);
-- the level titles reached this way are not announced.
select yg_mature_xp();
update achievements set shareable = false where code like 'nivel\_%';
