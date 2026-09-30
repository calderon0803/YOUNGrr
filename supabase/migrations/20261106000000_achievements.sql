-- Achievements ("Logros"). The database works them out from what already
-- exists (photos, friendships, events, Grr...), so they cannot be faked, and a
-- level once earned is never lost. Tiered ones have 4 levels (1 bronce,
-- 2 plata, 3 oro, 4 platino); the rest have a single level.
--
-- - They show on the profile, for whoever can see it.
-- - For 7 days after earning one (or a new level) you can share it: it then
--   appears in your friends' "Novedades".
-- - They are checked when you open your achievements, and every night.
-- - "Fundador": accounts created before version 1.0.0. On that release a
--   migration sets app_settings.founders_until and nobody else gets it.
-- The names, icons and texts live in src/config/achievements.js; the codes and
-- thresholds here must match it.

create table app_settings (
  key   text primary key,
  value text
);
alter table app_settings enable row level security;
revoke all on table app_settings from authenticated, anon;
insert into app_settings (key, value) values ('founders_until', null) on conflict (key) do nothing;

create table achievements (
  user_id   uuid not null references profiles (id) on delete cascade,
  code      text not null,
  level     int not null check (level between 1 and 4),
  earned_at timestamptz not null default now(),
  shared_at timestamptz,
  -- Only achievements earned from now on can be announced (not the ones
  -- everybody gets at once when achievements start, see the end).
  shareable boolean not null default true,
  primary key (user_id, code)
);
alter table achievements enable row level security;
revoke all on table achievements from authenticated, anon;

-- Code and thresholds: one per level.
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
    ('buen_rollo', array[10])
$$;

-- How far a person has got in one achievement.
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
    else 0
  end;
$$;

-- Awards what a person has earned. A new level starts a new 7-day share window.
create or replace function yg_check_achievements(person uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  d record;
  reached int;
begin
  if not exists (select 1 from profiles where id = person and not needs_setup) then return; end if;
  for d in select * from yg_achievement_defs() loop
    reached := (select count(*) from unnest(d.thresholds) t where t <= yg_achievement_metric(person, d.code));
    continue when reached = 0;
    insert into achievements (user_id, code, level, earned_at)
    values (person, d.code, reached, now())
    on conflict (user_id, code) do update
      set level = excluded.level, earned_at = now(), shared_at = null, shareable = true
      where achievements.level < excluded.level;
  end loop;
end;
$$;

-- Every night, for everyone (see the pg_cron block below).
create or replace function yg_check_all_achievements() returns int
language plpgsql volatile security definer set search_path = public as $$
declare
  person uuid;
  n int := 0;
begin
  for person in select id from profiles where not needs_setup loop
    perform yg_check_achievements(person);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- All achievements with your level and progress (checks them first).
create or replace function my_achievements() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_check_achievements(me);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'code', d.code,
      'thresholds', to_jsonb(d.thresholds),
      'level', coalesce(a.level, 0),
      'progress', yg_achievement_metric(me, d.code),
      'earned_at', a.earned_at,
      'shared_at', a.shared_at,
      'share_until', case when a.shareable and a.shared_at is null then a.earned_at + interval '7 days' end,
      'can_share', a.level is not null and a.shareable and a.shared_at is null and a.earned_at > now() - interval '7 days'
    ) order by d.ord)
    from (select *, row_number() over () as ord from yg_achievement_defs()) d
    left join achievements a on a.user_id = me and a.code = d.code
  ), '[]'::jsonb);
end;
$$;

-- The achievements someone has earned, for whoever can see their profile.
create or replace function user_achievements(target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when not can_view_profile(yg_me(), target) then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object('code', a.code, 'level', a.level, 'earned_at', a.earned_at) order by a.earned_at desc)
    from achievements a where a.user_id = target
  ), '[]'::jsonb) end;
$$;

-- Announces an achievement to your friends, within 7 days of earning it.
create or replace function share_achievement(what text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  update achievements set shared_at = now()
  where user_id = me and code = what and shareable and shared_at is null and earned_at > now() - interval '7 days';
  if not found then raise exception 'yg:conflict:Este logro ya no se puede compartir.'; end if;
  return my_achievements();
end;
$$;

grant execute on function my_achievements() to authenticated;
grant execute on function user_achievements(uuid) to authenticated;
grant execute on function share_achievement(text) to authenticated;

-- ---- Friends' news: shared achievements -----------------------------------------------------

create or replace function activity_block_json(me uuid, person uuid, since timestamptz, with_social boolean, last_at timestamptz) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'person', person_summary(person),
    'last_activity_at', last_at,
    'status', (select post_json(me, s.id) from posts s where s.author_id = person and s.kind = 'status'),
    'uploads', coalesce((
      select jsonb_agg(post_json(me, u.id) order by u.created_at desc)
      from (
        select id, created_at from posts
        where author_id = person and kind = 'album_upload' and created_at >= since
        order by created_at desc limit 3
      ) u
    ), '[]'::jsonb),
    'new_friends', case when with_social then coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(f.other), 'created_at', f.created_at) order by f.created_at desc)
      from (
        select case when fr.user_a = person then fr.user_b else fr.user_a end as other, fr.created_at
        from friendships fr
        where person in (fr.user_a, fr.user_b) and me not in (fr.user_a, fr.user_b) and fr.created_at >= since
        order by fr.created_at desc limit 5
      ) f
    ), '[]'::jsonb) else '[]'::jsonb end,
    'new_friends_total', case when with_social then (
      select count(*) from friendships fr
      where person in (fr.user_a, fr.user_b) and me not in (fr.user_a, fr.user_b) and fr.created_at >= since
    ) else 0 end,
    'tagged', case when with_social then coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'storage_path', t.storage_path, 'width', t.width, 'height', t.height) order by t.at desc)
      from (
        select ph.id, ph.storage_path, ph.width, ph.height, pt.created_at as at
        from photo_tags pt join photos ph on ph.id = pt.photo_id
        where pt.user_id = person and pt.created_at >= since and can_view_photo(me, ph.id)
        order by pt.created_at desc limit 4
      ) t
    ), '[]'::jsonb) else '[]'::jsonb end,
    'tagged_total', case when with_social then (
      select count(*) from photo_tags pt
      where pt.user_id = person and pt.created_at >= since and can_view_photo(me, pt.photo_id)
    ) else 0 end,
    -- Achievements the person chose to share lately.
    'achievements', case when with_social then coalesce((
      select jsonb_agg(jsonb_build_object('code', a.code, 'level', a.level, 'shared_at', a.shared_at) order by a.shared_at desc)
      from achievements a where a.user_id = person and a.shared_at >= since
    ), '[]'::jsonb) else '[]'::jsonb end
  );
$$;

create or replace function friend_activity(before timestamptz default null, page_size int default 8) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id, now() - interval '30 days' as since),
  friends as (
    select case when f.user_a = me.id then f.user_b else f.user_a end as id
    from friendships f, me where me.id in (f.user_a, f.user_b)
  ),
  events as (
    select po.author_id as person, po.created_at as at
    from posts po, me where po.author_id in (select id from friends) and po.created_at >= me.since
    union all
    select fd.id, fr.created_at
    from friendships fr join friends fd on fd.id in (fr.user_a, fr.user_b), me
    where me.id not in (fr.user_a, fr.user_b) and fr.created_at >= me.since
    union all
    select pt.user_id, pt.created_at
    from photo_tags pt, me
    where pt.user_id in (select id from friends) and pt.created_at >= me.since and can_view_photo(me.id, pt.photo_id)
    union all
    select a.user_id, a.shared_at
    from achievements a, me
    where a.user_id in (select id from friends) and a.shared_at >= me.since
  ),
  page as (
    select person, max(at) as last_at from events group by person
    having before is null or max(at) < before
    order by last_at desc
    limit least(page_size, 30) + 1
  )
  select coalesce(jsonb_agg(activity_block_json(me.id, page.person, me.since, true, page.last_at) order by page.last_at desc), '[]'::jsonb)
  from page, me;
$$;

-- ---- Data export: your achievements ----------------------------------------------------------

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
        'with', (select coalesce(jsonb_agg(p.first_name || ' ' || p.last_name), '[]'::jsonb) from conversation_members cm join profiles p on p.id = cm.user_id
                 where cm.conversation_id = c.conversation_id and cm.user_id <> c.user_id),
        'messages', coalesce((select jsonb_agg(jsonb_build_object(
            'from', case when m.sender_id = c.user_id then 'yo' else (select p.first_name || ' ' || p.last_name from profiles p where p.id = m.sender_id) end,
            'text', case when m.deleted_at is null then m.text end,
            'deleted', m.deleted_at is not null,
            'created_at', m.created_at) order by m.created_at)
          from messages m where m.conversation_id = c.conversation_id), '[]'::jsonb)))
      from conversation_members c, me where c.user_id = me.id), '[]'::jsonb),
    'invitations_sent', coalesce((select jsonb_agg(jsonb_build_object('email', i.email, 'created_at', i.created_at, 'expires_at', i.expires_at, 'used', i.used_by is not null))
      from invitations i, me where i.inviter_id = me.id), '[]'::jsonb),
    'achievements', coalesce((select jsonb_agg(jsonb_build_object('code', a.code, 'level', a.level, 'earned_at', a.earned_at, 'shared_at', a.shared_at) order by a.earned_at)
      from achievements a, me where a.user_id = me.id), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('about', r.target_type, 'reason', r.reason, 'status', r.status, 'created_at', r.created_at))
      from reports r, me where r.reporter_id = me.id), '[]'::jsonb)
  );
$$;

-- ---- Every night: check everyone's achievements -------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('youngrr-achievements', '30 3 * * *', 'select public.yg_check_all_achievements()');
  end if;
exception when others then
  raise notice 'pg_cron no disponible: programa yg_check_all_achievements() a mano (%).', sqlerrm;
end;
$$;

-- ---- The privacy policy now explains achievements: everyone accepts it again ----------------
-- Must match LEGAL.version in src/config/app.js.
create or replace function yg_terms_version() returns text
language sql immutable as $$ select '2026-09-30'::text $$;

-- ---- Start: what everybody has already earned, without announcing it ------------------------
select yg_check_all_achievements();
update achievements set shareable = false;
