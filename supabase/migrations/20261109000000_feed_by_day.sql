-- Friends' news: one card per friend and day (Spanish time) instead of one card
-- per friend that keeps moving up. New activity makes a new card on top; the
-- cards of other days stay as they were further down. Each card holds only what
-- the person did that day; their current status shows in the card of the day
-- they set it. Same for "Cerca de ti".

create or replace function yg_local_day(at timestamptz) returns date
language sql immutable as $$ select (at at time zone 'Europe/Madrid')::date $$;

-- One person's card for one day.
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
    'achievements', case when with_social then coalesce((
      select jsonb_agg(jsonb_build_object('code', a.code, 'level', a.level, 'shared_at', a.shared_at) order by a.shared_at desc)
      from achievements a where a.user_id = person and a.shared_at >= b.from_at and a.shared_at < b.to_at
    ), '[]'::jsonb) else '[]'::jsonb end
  )
  from b;
$$;

-- Cards of the last 30 days, newest first. Returns page_size + 1 cards so the
-- app knows if there are more; `before` is the last card's latest activity.
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
    select person, yg_local_day(at) as day, max(at) as last_at from events
    group by person, yg_local_day(at)
    having before is null or max(at) < before
    order by last_at desc
    limit least(page_size, 30) + 1
  )
  select coalesce(jsonb_agg(activity_day_json(me.id, page.person, page.day, true, page.last_at) order by page.last_at desc), '[]'::jsonb)
  from page, me;
$$;

create or replace function nearby_activity(radius_km int, before timestamptz default null, page_size int default 8) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  origin profiles;
  since timestamptz := now() - interval '30 days';
  items jsonb;
begin
  if radius_km not in (10, 25, 50) then raise exception 'yg:validation:Radio no válido.'; end if;
  select * into origin from profiles where id = me;
  if origin.city_lat is null or origin.city_lng is null then
    return jsonb_build_object('needs_location', true, 'origin_city', '', 'items', '[]'::jsonb);
  end if;

  select coalesce(jsonb_agg(
    activity_day_json(me, page.person, page.day, false, page.last_at) || jsonb_build_object('nearby', jsonb_build_object(
      'city', case when can_view_city(me, page.person) then page.city end,
      'distance_km', case when not can_view_city(me, page.person) and can_view_distance(me, page.person) then round(page.km)::int end
    ))
    order by page.last_at desc
  ), '[]'::jsonb)
  into items
  from (
    select a.id as person, a.city, yg_local_day(po.created_at) as day, max(po.created_at) as last_at,
           distance_km(origin.city_lat, origin.city_lng, a.city_lat, a.city_lng) as km
    from posts po
    join profiles a on a.id = po.author_id
    where a.id <> me
      and a.city_lat is not null and a.city_lng is not null
      and distance_km(origin.city_lat, origin.city_lng, a.city_lat, a.city_lng) <= radius_km
      and can_view_profile(me, a.id)
      and po.created_at >= since
    group by a.id, a.city, a.city_lat, a.city_lng, yg_local_day(po.created_at)
    having before is null or max(po.created_at) < before
    order by last_at desc
    limit least(page_size, 30) + 1
  ) page;

  return jsonb_build_object('needs_location', false, 'origin_city', origin.city, 'items', items);
end;
$$;
