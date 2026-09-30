-- Tastes: the music artists, films and series you like, in your profile.
--
-- - They come from catalogues (films and series from TMDB, artists from
--   MusicBrainz), so the same title is the same everywhere; the app saves the
--   catalogue id, the title, the year and the poster.
-- - Films and series are rated with stars, from 0.5 to 5 in halves; artists
--   are just liked.
-- - They are seen by whoever can see your profile, and what you add or rate
--   appears in your friends' news (and in a group's news, for the people you
--   show your whole profile).

create table tastes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles (id) on delete cascade,
  kind        text not null check (kind in ('artist', 'movie', 'series')),
  source      text not null check (source in ('tmdb', 'musicbrainz')),
  external_id text not null check (char_length(external_id) between 1 and 64),
  title       text not null check (char_length(title) between 1 and 200),
  year        int check (year between 1800 and 2200),
  -- TMDB poster path ("/abc.jpg"); the app builds the image address.
  image_path  text check (image_path is null or image_path ~ '^/[A-Za-z0-9_-]{1,60}\.(jpg|png)$'),
  rating      numeric(2, 1) check (rating is null or (rating between 0.5 and 5 and rating * 2 = floor(rating * 2))),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, kind, source, external_id),
  check ((kind = 'artist') = (rating is null)),
  check ((kind = 'artist') = (source = 'musicbrainz'))
);
create index tastes_user on tastes (user_id, kind, updated_at desc);
alter table tastes enable row level security;
revoke all on table tastes from authenticated, anon;
create trigger rate_limit_tastes before insert on tastes for each row execute function on_rate_limited_insert('taste', '30');

create or replace function taste_json(t tastes) returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'id', t.id, 'kind', t.kind, 'source', t.source, 'external_id', t.external_id, 'title', t.title,
    'year', t.year, 'image_path', t.image_path, 'rating', t.rating, 'updated_at', t.updated_at
  );
$$;

-- A person's tastes, for whoever can see their profile; the best rated first.
create or replace function list_tastes(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not can_view_profile(me, target) then raise exception 'yg:forbidden:No puedes ver los gustos de esta persona.'; end if;
  return coalesce((
    select jsonb_agg(taste_json(t) order by t.kind, t.rating desc nulls last, t.updated_at desc)
    from tastes t where t.user_id = target
  ), '[]'::jsonb);
end;
$$;

-- Adds a taste or changes its stars.
create or replace function set_taste(taste_kind text, catalog text, catalog_id text, taste_title text, taste_year int, poster text, stars numeric)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  saved tastes;
begin
  taste_title := trim(coalesce(taste_title, ''));
  if taste_kind not in ('artist', 'movie', 'series') then raise exception 'yg:validation:Tipo no válido.'; end if;
  if taste_kind = 'artist' then stars := null;
  elsif stars is null or stars < 0.5 or stars > 5 or stars * 2 <> floor(stars * 2) then
    raise exception 'yg:validation:Elige de media a cinco estrellas.';
  end if;
  if (select count(*) from tastes t where t.user_id = me and t.kind = taste_kind) >= 500 then
    raise exception 'yg:conflict:Has llegado al máximo de 500.';
  end if;
  insert into tastes as t (user_id, kind, source, external_id, title, year, image_path, rating)
  values (me, taste_kind, catalog, catalog_id, taste_title, taste_year, poster, stars)
  on conflict (user_id, kind, source, external_id) do update
    set rating = excluded.rating, title = excluded.title, year = excluded.year, image_path = excluded.image_path, updated_at = now()
  returning * into saved;
  return taste_json(saved);
end;
$$;

create or replace function remove_taste(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from tastes where id = target and user_id = yg_me();
end;
$$;

grant execute on function list_tastes(uuid) to authenticated;
grant execute on function set_taste(text, text, text, text, int, text, numeric) to authenticated;
grant execute on function remove_taste(uuid) to authenticated;

-- ---- In the news ----------------------------------------------------------------------------------

create or replace function activity_day_json(me uuid, person uuid, day date, with_social boolean, last_at timestamptz) returns jsonb
language sql stable security definer set search_path = public as $$
  with b as (
    select (day::timestamp at time zone 'Europe/Madrid') as from_at,
           ((day + 1)::timestamp at time zone 'Europe/Madrid') as to_at
  )
  select jsonb_build_object(
    'person', person_summary(person),
    'day', day,
    'last_activity_at', last_at,
    'status', (select post_json(me, s.id) from posts s where s.author_id = person and s.kind = 'status' and s.created_at >= b.from_at and s.created_at < b.to_at),
    'uploads', coalesce((
      select jsonb_agg(post_json(me, u.id) order by u.created_at desc)
      from (
        select id, created_at from posts
        where author_id = person and kind = 'album_upload' and created_at >= b.from_at and created_at < b.to_at
        order by created_at desc limit 3
      ) u
    ), '[]'::jsonb),
    'uploads_total', (select count(*) from posts where author_id = person and kind = 'album_upload' and created_at >= b.from_at and created_at < b.to_at),
    'new_friends', case when with_social then coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(f.other), 'created_at', f.created_at) order by f.created_at desc)
      from (
        select case when fr.user_a = person then fr.user_b else fr.user_a end as other, fr.created_at
        from friendships fr
        where person in (fr.user_a, fr.user_b) and me not in (fr.user_a, fr.user_b) and fr.created_at >= b.from_at and fr.created_at < b.to_at
        order by fr.created_at desc limit 5
      ) f
    ), '[]'::jsonb) else '[]'::jsonb end,
    'new_friends_total', case when with_social then (
      select count(*) from friendships fr
      where person in (fr.user_a, fr.user_b) and me not in (fr.user_a, fr.user_b) and fr.created_at >= b.from_at and fr.created_at < b.to_at
    ) else 0 end,
    'tagged', case when with_social then coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'storage_path', t.storage_path, 'width', t.width, 'height', t.height) order by t.at desc)
      from (
        select ph.id, ph.storage_path, ph.width, ph.height, pt.created_at as at
        from photo_tags pt join photos ph on ph.id = pt.photo_id
        where pt.user_id = person and pt.created_at >= b.from_at and pt.created_at < b.to_at and can_view_photo(me, ph.id)
        order by pt.created_at desc limit 4
      ) t
    ), '[]'::jsonb) else '[]'::jsonb end,
    'tagged_total', case when with_social then (
      select count(*) from photo_tags pt
      where pt.user_id = person and pt.created_at >= b.from_at and pt.created_at < b.to_at and can_view_photo(me, pt.photo_id)
    ) else 0 end,
    -- Films and series rated, and artists liked, that day.
    'tastes', coalesce((
      select jsonb_agg(taste_json(t) order by t.updated_at desc)
      from (select * from tastes where user_id = person and updated_at >= b.from_at and updated_at < b.to_at order by updated_at desc limit 6) t
    ), '[]'::jsonb),
    'tastes_total', (select count(*) from tastes where user_id = person and updated_at >= b.from_at and updated_at < b.to_at),
    'achievements', case when with_social then coalesce((
      select jsonb_agg(jsonb_build_object('code', a.code, 'level', a.level, 'shared_at', a.shared_at) order by a.shared_at desc)
      from achievements a where a.user_id = person and a.shared_at >= b.from_at and a.shared_at < b.to_at
    ), '[]'::jsonb) else '[]'::jsonb end
  )
  from b;
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
    union all
    select t.user_id, t.updated_at
    from tastes t, me
    where t.user_id in (select id from friends) and t.updated_at >= me.since and can_view_profile(me.id, t.user_id)
  ),
  page as (
    select person, yg_local_day(at) as day, max(at) as last_at from events
    group by person, yg_local_day(at)
    having before is null or max(at) < before
    order by last_at desc
    limit least(page_size, 30) + 1
  )
  select coalesce(jsonb_agg(activity_day_json(me.id, page.person, page.day, true, page.last_at) order by page.last_at desc), '[]'::jsonb)
  from page, me;
$$;

create or replace function group_activity(target uuid, before timestamptz default null, page_size int default 8) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  size int := least(greatest(page_size, 1), 30);
begin
  perform yg_require_group_member(me, target);
  return coalesce((
    with since as (select now() - interval '30 days' as at),
    people as (
      select m.user_id as id from group_members m
      where m.group_id = target and m.user_id <> me and can_view_profile(me, m.user_id)
    ),
    person_events as (
      select po.author_id as person, po.created_at as at from posts po, since
      where po.author_id in (select id from people) and po.created_at >= since.at
      union all
      select pp.id, fr.created_at from friendships fr join people pp on pp.id in (fr.user_a, fr.user_b), since
      where me not in (fr.user_a, fr.user_b) and fr.created_at >= since.at
      union all
      select pt.user_id, pt.created_at from photo_tags pt, since
      where pt.user_id in (select id from people) and pt.created_at >= since.at and can_view_photo(me, pt.photo_id)
      union all
      select a.user_id, a.shared_at from achievements a, since
      where a.user_id in (select id from people) and a.shared_at >= since.at
      union all
      select t.user_id, t.updated_at from tastes t, since
      where t.user_id in (select id from people) and t.updated_at >= since.at
    ),
    items as (
      select 'person' as kind, person, yg_local_day(at) as day, max(at) as last_at, null::uuid as event_id
      from person_events group by person, yg_local_day(at)
      union all
      select 'joined', null, yg_local_day(m.joined_at), max(m.joined_at), null
      from group_members m, since
      where m.group_id = target and m.joined_at >= since.at and (m.user_id = me or not is_blocked_between(me, m.user_id))
      group by yg_local_day(m.joined_at)
      union all
      select 'event', e.creator_id, yg_local_day(e.created_at), e.created_at, e.id
      from events e, since where e.group_id = target and e.created_at >= since.at and can_see_event(me, e.id)
    ),
    page as (
      select * from items where before is null or last_at < before order by last_at desc limit size + 1
    )
    select jsonb_agg(
      case page.kind
        when 'person' then jsonb_build_object('kind', 'person', 'block', activity_day_json(me, page.person, page.day, true, page.last_at), 'last_activity_at', page.last_at)
        when 'joined' then jsonb_build_object('kind', 'joined', 'day', page.day, 'last_activity_at', page.last_at, 'people', (
          select coalesce(jsonb_agg(person_summary(m.user_id) order by m.joined_at desc), '[]'::jsonb)
          from group_members m
          where m.group_id = target and yg_local_day(m.joined_at) = page.day and (m.user_id = me or not is_blocked_between(me, m.user_id))))
        else jsonb_build_object('kind', 'event', 'event', event_json(me, page.event_id), 'last_activity_at', page.last_at)
      end order by page.last_at desc)
    from page
  ), '[]'::jsonb);
end;
$$;

-- ---- Data export -------------------------------------------------------------------------------------

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
        'profile_share', gm.profile_share, 'notify', gm.notify) order by gm.joined_at)
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
