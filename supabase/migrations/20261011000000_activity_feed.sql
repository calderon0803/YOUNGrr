-- Friends' news as activity, Tuenti style: no free posts any more. Each person
-- has at most one status (a short phrase); photo uploads, new friendships and
-- photo tags are the rest of the activity. The home page shows one block per
-- friend with their status and what they have done lately.

-- ---- From posts to statuses ------------------------------------------------------
-- Posts with a photo go away (the photo stays in its album); of the text-only
-- ones, each person keeps the latest as their status.

delete from posts where kind = 'post' and photo_id is not null;
delete from posts p
where p.kind = 'post'
  and exists (
    select 1 from posts q
    where q.author_id = p.author_id and q.kind = 'post' and (q.created_at, q.id) > (p.created_at, p.id)
  );
alter table posts drop constraint if exists posts_kind_check;
update posts set kind = 'status', text = left(trim(text), 140) where kind = 'post';
delete from notifications n
where n.type in ('grr_post', 'comment_post') and not exists (select 1 from posts p where p.id = n.target_id);

alter table posts add constraint posts_kind_check check (kind in ('status', 'album_upload'));
alter table posts alter column kind set default 'status';
alter table posts add constraint posts_status_text check (kind <> 'status' or char_length(text) between 1 and 140);
create unique index posts_one_status on posts (author_id) where kind = 'status';

drop function if exists create_post(text, text, int, int);
drop function if exists update_post(uuid, text);
drop function if exists get_feed(timestamptz, int);
drop function if exists get_user_posts(uuid, timestamptz, int);
drop function if exists get_nearby_feed(int, timestamptz, int);
drop function if exists nearby_posts(int, timestamptz, int);
drop function if exists hide_post(uuid, boolean);
drop function if exists posts_page(uuid[]);

-- ---- Status ----------------------------------------------------------------------------

-- The new status replaces the previous one (with its comments and Grr).
create or replace function set_status(body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  body := trim(coalesce(body, ''));
  if body = '' then raise exception 'yg:validation:Escribe tu estado.'; end if;
  if char_length(body) > 140 then raise exception 'yg:validation:El estado no puede superar los 140 caracteres.'; end if;
  delete from notifications where target_id in (select id from posts where author_id = me and kind = 'status');
  delete from posts where author_id = me and kind = 'status';
  insert into posts (author_id, kind, text) values (me, 'status', body) returning id into new_id;
  return post_json(me, new_id);
end;
$$;

-- ---- Activity blocks -------------------------------------------------------------------

-- One person's block: current status, recent album uploads and, for friends,
-- new friendships and photos where they were tagged (that the viewer can see).
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
    ) else 0 end
  );
$$;

-- Friends with activity in the last 30 days, most recent first. Returns
-- page_size + 1 blocks so the app knows if there are more.
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

-- "Cerca de ti": status and album uploads of people whose town is within
-- radius_km and whose profile you can see. Town and distance follow their own
-- privacy; the distance is only given when the town is hidden.
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
    activity_block_json(me, page.person, since, false, page.last_at) || jsonb_build_object('nearby', jsonb_build_object(
      'city', case when can_view_city(me, page.person) then page.city end,
      'distance_km', case when not can_view_city(me, page.person) and can_view_distance(me, page.person) then round(page.km)::int end
    ))
    order by page.last_at desc
  ), '[]'::jsonb)
  into items
  from (
    select a.id as person, a.city, max(po.created_at) as last_at,
           distance_km(origin.city_lat, origin.city_lng, a.city_lat, a.city_lng) as km
    from posts po
    join profiles a on a.id = po.author_id
    where a.id <> me
      and a.city_lat is not null and a.city_lng is not null
      and distance_km(origin.city_lat, origin.city_lng, a.city_lat, a.city_lng) <= radius_km
      and can_view_profile(me, a.id)
      and po.created_at >= since
    group by a.id, a.city, a.city_lat, a.city_lng
    having before is null or max(po.created_at) < before
    order by last_at desc
    limit least(page_size, 30) + 1
  ) page;

  return jsonb_build_object('needs_location', false, 'origin_city', origin.city, 'items', items);
end;
$$;

grant execute on function set_status(text) to authenticated;
grant execute on function friend_activity(timestamptz, int) to authenticated;
grant execute on function nearby_activity(int, timestamptz, int) to authenticated;
