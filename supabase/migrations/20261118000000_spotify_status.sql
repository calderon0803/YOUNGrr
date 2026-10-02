-- Spotify links in the status.
-- When a status carries a link to open.spotify.com (a song, album, playlist,
-- artist, podcast or episode), the author's browser asks Spotify (oEmbed, no
-- key) for its title and cover and sends them with the status. They are kept
-- with it, so whoever sees the status does not contact Spotify, except to load
-- the cover from its servers. The database only keeps them if they match the
-- link written in the text and the cover is a Spotify image.

alter table posts add column link jsonb;
alter table posts add constraint posts_link_status check (link is null or kind = 'status');

-- The Spotify data of a status, cleaned: null if it does not match the text.
create or replace function yg_clean_spotify(body text, link jsonb) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  kind text := link ->> 'kind';
  item text := link ->> 'id';
  title text := left(trim(coalesce(link ->> 'title', '')), 200);
  image text := link ->> 'image';
begin
  if link is null or jsonb_typeof(link) <> 'object' then return null; end if;
  if kind is null or kind not in ('track', 'album', 'playlist', 'artist', 'show', 'episode') then return null; end if;
  if item is null or item !~ '^[A-Za-z0-9]{22}$' then return null; end if;
  if position('open.spotify.com/' || kind || '/' || item in coalesce(body, '')) = 0 then return null; end if;
  if title = '' then return null; end if;
  if image is not null and image !~ '^https://(i\.scdn\.co|image-cdn-[a-z]{2}\.spotifycdn\.com|mosaic\.scdn\.co)/image/[a-f0-9]{20,80}$' then
    image := null;
  end if;
  return jsonb_build_object('kind', kind, 'id', item, 'title', title, 'image', image);
end;
$$;
revoke all on function yg_clean_spotify(text, jsonb) from public, authenticated, anon;

drop function set_status(text);
create or replace function set_status(body text, link jsonb default null) returns jsonb
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
  insert into posts (author_id, kind, text, link) values (me, 'status', body, yg_clean_spotify(body, link)) returning id into new_id;
  return post_json(me, new_id);
end;
$$;
grant execute on function set_status(text, jsonb) to authenticated;

-- ---- The link travels with the status ---------------------------------------------------------------

create or replace function post_json(viewer uuid, post_id uuid, comment_preview int default 3) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', po.id,
    'kind', po.kind,
    'author_id', po.author_id,
    'text', po.text,
    'link', po.link,
    'photo_id', po.photo_id,
    'created_at', po.created_at,
    'updated_at', po.updated_at,
    'author', jsonb_build_object('id', a.id, 'first_name', a.first_name, 'last_name', a.last_name, 'avatar_url', a.avatar_url),
    'photo', case when ph.id is null then null else jsonb_build_object(
      'id', ph.id, 'storage_path', ph.storage_path, 'width', ph.width, 'height', ph.height, 'album_id', ph.album_id
    ) end,
    'album', case when po.album_id is null then null else (
      select jsonb_build_object('id', al.id, 'title', al.title, 'kind', al.kind) from albums al where al.id = po.album_id
    ) end,
    'photos', case when po.kind = 'album_upload' then coalesce((
      select jsonb_agg(jsonb_build_object('id', p2.id, 'storage_path', p2.storage_path, 'width', p2.width, 'height', p2.height) order by t.ord)
      from unnest(po.photo_ids) with ordinality as t(id, ord)
      join photos p2 on p2.id = t.id
      where t.ord <= 6
    ), '[]'::jsonb) else '[]'::jsonb end,
    'photo_total', case when po.kind = 'album_upload' then (select count(*) from photos p3 where p3.id = any(po.photo_ids)) else 0 end,
    'grr_count', (select count(*) from grrs g where g.post_id = po.id),
    'has_grr', exists (select 1 from grrs g where g.post_id = po.id and g.user_id = viewer),
    'grr_by', grr_by_json(viewer, po.id),
    'comment_count', (select count(*) from comments c where c.post_id = po.id),
    'comments', comments_json(po.id, null, comment_preview)
  )
  from posts po
  join profiles a on a.id = po.author_id
  left join photos ph on ph.id = po.photo_id
  where po.id = post_json.post_id;
$$;

create or replace function profile_view(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p profiles;
  visible boolean;
  info boolean;
  latest posts;
begin
  select * into p from profiles where id = target;
  if not found then
    raise exception 'yg:not_found:Esta persona no existe o ha eliminado su cuenta.';
  end if;
  visible := can_view_profile(me, target);
  info := yg_can_view_info(me, target);
  if visible then
    select * into latest from posts where author_id = target and kind = 'status' limit 1;
  end if;
  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', p.id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'avatar_url', p.avatar_url,
      'cover_path', case when visible then p.cover_path end,
      'city', case when can_view_city(me, target) then p.city else '' end,
      'city_lat', null,
      'city_lng', null,
      'visit_count', case when me = target then p.visit_count end,
      'bio', case when info then p.bio else '' end,
      'birthday', case when me = target then p.birthday end,
      'birthday_day', case when info and p.birthday is not null then to_char(p.birthday, 'MM-DD') end,
      'studies', case when info then p.studies else '' end,
      'work', case when info then p.work else '' end,
      'created_at', p.created_at
    ),
    'friendship', friendship_status(me, target),
    'friends_count', (select count(*) from friendships where target in (user_a, user_b)),
    'mutual_friends', mutual_friends(me, target),
    'posts_count', case when visible then (select count(*) from posts where author_id = target) else 0 end,
    'photos_count', case when visible then (select count(*) from photos where owner_id = target) else 0 end,
    'can_view_profile', visible,
    'can_view_info', info,
    'can_send_request', friendship_status(me, target) = 'none' and can_send_request(me, target),
    'visits', case when me = target then p.visit_count end,
    'status', case when latest.id is null then null else jsonb_build_object('post_id', latest.id, 'text', latest.text, 'link', latest.link, 'created_at', latest.created_at) end
  );
end;
$$;

create or replace function update_post(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  po posts;
begin
  select * into po from posts where id = target;
  if po.id is null then raise exception 'yg:not_found:Esta publicación ya no existe.'; end if;
  if po.author_id <> me then raise exception 'yg:forbidden:Solo puedes editar tus publicaciones.'; end if;
  body := trim(coalesce(body, ''));
  if body = '' and po.photo_id is null then raise exception 'yg:validation:La publicación no puede quedar vacía.'; end if;
  if char_length(body) > 2000 then raise exception 'yg:validation:La publicación no puede superar los 2000 caracteres.'; end if;
  update posts set text = body, link = yg_clean_spotify(body, link), updated_at = now() where id = target;
  return post_json(me, target);
end;
$$;

-- ---- Data export: the Spotify link of your status ------------------------------------------------------

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
    'status', (select jsonb_build_object('text', po.text, 'link', po.link, 'created_at', po.created_at) from posts po, me where po.author_id = me.id and po.kind = 'status'),
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
