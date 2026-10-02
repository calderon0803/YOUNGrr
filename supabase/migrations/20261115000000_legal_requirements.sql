-- Legal requirements before opening YOUNGrr to the public.
--
-- - Illegal content (Digital Services Act, art. 16): any report saying that
--   something is illegal, with its type and an explanation, reaches the
--   moderators on its own, without the minimum of reports of the other reasons.
--   People without an account report it by email (the "Avisar de contenido
--   ilegal" page).
-- - Statement of reasons (art. 17): when content is removed, the notice to its
--   owner says which rule of the terms it broke (or that it is illegal), that
--   a person decided it, and how to appeal.
-- - Place groups: whoever joins is told their name will be seen by the whole
--   group, and can choose to only count in the total.

-- ---- Reports of illegal content ----------------------------------------------------------------

alter table reports
  add column illegal boolean not null default false,
  add column illegal_category text check (illegal_category in ('crime', 'privacy', 'copyright', 'minors', 'hate')),
  add column details text check (char_length(details) <= 1000);

drop function if exists report_content(text, uuid, text);
create or replace function report_content(kind text, target uuid, reason text, details text default null, illegal_category text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  owner uuid;
  copy jsonb;
begin
  reason := trim(coalesce(reason, ''));
  if reason = '' or char_length(reason) > 200 then raise exception 'yg:validation:Elige un motivo.'; end if;
  details := nullif(trim(coalesce(details, '')), '');
  if illegal_category is not null then
    if illegal_category not in ('crime', 'privacy', 'copyright', 'minors', 'hate') then raise exception 'yg:validation:Elige qué tipo de contenido ilegal es.'; end if;
    if char_length(coalesce(details, '')) not between 10 and 1000 then
      raise exception 'yg:validation:Explica por qué es ilegal (entre 10 y 1000 caracteres).';
    end if;
  end if;

  if kind = 'status' then
    select p.author_id, jsonb_build_object('text', p.text, 'kind', p.kind) into owner, copy
    from posts p where p.id = target and can_view_post(me, p.author_id);
  elsif kind = 'photo' then
    select ph.owner_id, jsonb_build_object('storage_path', ph.storage_path, 'caption', ph.caption) into owner, copy
    from photos ph where ph.id = target and can_view_photo(me, ph.id);
  elsif kind = 'comment' then
    select c.author_id, jsonb_build_object('text', c.text, 'on', case when c.post_id is not null then 'status' else 'photo' end) into owner, copy
    from comments c
    where c.id = target
      and ((c.post_id is not null and exists (select 1 from posts p where p.id = c.post_id and can_view_post(me, p.author_id)))
        or (c.photo_id is not null and can_view_photo(me, c.photo_id)));
  elsif kind = 'wall_message' then
    select w.author_id, jsonb_build_object('text', w.text, 'profile_id', w.profile_id) into owner, copy
    from wall_messages w where w.id = target and can_view_profile(me, w.profile_id);
  elsif kind = 'message' then
    select m.sender_id, jsonb_build_object('text', m.text) into owner, copy
    from messages m where m.id = target and m.deleted_at is null and is_conversation_member(m.conversation_id, me);
  elsif kind = 'group_post' then
    select p.author_id, jsonb_build_object('text', p.text, 'storage_path', p.photo_path, 'group', g.name) into owner, copy
    from group_posts p join groups g on g.id = p.group_id
    where p.id = target and yg_is_group_member(p.group_id, me);
  elsif kind = 'group_reply' then
    select r.author_id, jsonb_build_object('text', r.text, 'group', g.name) into owner, copy
    from group_replies r join group_posts p on p.id = r.post_id join groups g on g.id = p.group_id
    where r.id = target and yg_is_group_member(p.group_id, me);
  elsif kind = 'profile' then
    select p.id, jsonb_build_object('name', p.first_name || ' ' || p.last_name, 'bio', p.bio, 'avatar_url', p.avatar_url) into owner, copy
    from profiles p where p.id = target;
  else
    raise exception 'yg:validation:Tipo de contenido no válido.';
  end if;

  if owner is null then raise exception 'yg:not_found:Este contenido ya no existe.'; end if;
  if owner = me then raise exception 'yg:validation:No puedes reportar tu propio contenido.'; end if;

  insert into reports as r (reporter_id, post_id, reason, target_type, target_id, target_owner_id, snapshot, illegal, illegal_category, details)
  values (me, case when kind = 'status' then target end, reason, kind, target, owner, copy,
          illegal_category is not null, illegal_category, details)
  on conflict (reporter_id, target_type, target_id) where status = 'pending' do update
    -- Reporting again as illegal upgrades the report you already sent.
    set illegal = r.illegal or excluded.illegal,
        illegal_category = coalesce(excluded.illegal_category, r.illegal_category),
        details = coalesce(excluded.details, r.details),
        reason = case when excluded.illegal then excluded.reason else r.reason end;
end;
$$;
grant execute on function report_content(text, uuid, text, text, text) to authenticated;

-- An illegal report reaches moderation on its own.
create or replace function list_reports(filter text default 'pending') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_require_moderator();
  if filter not in ('pending', 'resolved', 'dismissed', 'all') then raise exception 'yg:validation:Filtro no válido.'; end if;
  return coalesce((
    select jsonb_agg(g.item order by g.illegal desc, g.last_at desc)
    from (
      select
        jsonb_build_object(
          'id', (array_agg(r.id order by r.created_at desc))[1],
          'target_type', r.target_type,
          'target_id', r.target_id,
          'report_count', count(*),
          'reasons', (
            select jsonb_object_agg(x.reason, x.n) from (
              select r2.reason, count(*) as n from reports r2
              where r2.target_type = r.target_type and r2.target_id = r.target_id and (filter = 'all' or r2.status = filter)
              group by r2.reason
            ) x),
          'illegal', bool_or(r.illegal),
          'illegal_categories', coalesce((select jsonb_agg(distinct c) from unnest(array_agg(r.illegal_category)) c where c is not null), '[]'::jsonb),
          -- What the people who reported it explained (never who they are).
          'details', coalesce((select jsonb_agg(d) from (select unnest(array_agg(r.details order by r.created_at desc)) d) x where d is not null), '[]'::jsonb),
          'created_at', min(r.created_at),
          'last_reported_at', max(r.created_at),
          'status', (array_agg(r.status order by r.created_at desc))[1],
          'snapshot', (array_agg(r.snapshot order by r.created_at desc))[1],
          'content_exists', yg_report_content_exists((array_agg(r order by r.created_at desc))[1]),
          'content_removed', bool_or(r.content_removed),
          'target_owner', (select person_summary(o) from unnest(array_agg(r.target_owner_id)) o where o is not null limit 1),
          'resolved_by', (select person_summary(b) from unnest(array_agg(r.resolved_by order by r.resolved_at desc nulls last)) b where b is not null limit 1),
          'resolved_at', max(r.resolved_at),
          'resolution_note', (array_agg(r.resolution_note order by r.resolved_at desc nulls last))[1]
        ) as item,
        bool_or(r.illegal) as illegal,
        max(r.created_at) as last_at
      from reports r
      where filter = 'all' or r.status = filter
      group by r.target_type, r.target_id
      having filter <> 'pending' or bool_or(r.illegal) or count(*) >= yg_report_threshold(r.target_type, r.target_id)
      order by bool_or(r.illegal) desc, max(r.created_at) desc
      limit 200
    ) g
  ), '[]'::jsonb);
end;
$$;

create or replace function moderation_pending_count() returns int
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_require_moderator();
  return (
    select count(*) from (
      select 1 from reports r where r.status = 'pending'
      group by r.target_type, r.target_id
      having bool_or(r.illegal) or count(*) >= yg_report_threshold(r.target_type, r.target_id)
    ) g
  ) + (select count(*) from moderation_removals where appealed_at is not null and decision is null);
end;
$$;

-- ---- Statement of reasons when removing ------------------------------------------------------------

alter table moderation_removals
  add column rule text check (rule in ('harassment', 'hate', 'sexual', 'minors', 'personal_data', 'spam', 'illegal', 'rights', 'security')),
  -- Removals are decided by a person (the upload filter never removes anything).
  add column automated boolean not null default false;

drop function if exists resolve_report(uuid, text, boolean, text);
create or replace function resolve_report(target uuid, decision text, remove_content boolean default false, note text default '', rule text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  r reports;
begin
  perform yg_require_moderator();
  if decision not in ('resolved', 'dismissed') then raise exception 'yg:validation:Decisión no válida.'; end if;
  select * into r from reports where id = target;
  if r.id is null then raise exception 'yg:not_found:Este reporte ya no existe.'; end if;
  note := trim(coalesce(note, ''));
  if char_length(note) > 500 then raise exception 'yg:validation:La nota no puede superar los 500 caracteres.'; end if;

  if remove_content and decision = 'resolved' then
    if rule is null or rule not in ('harassment', 'hate', 'sexual', 'minors', 'personal_data', 'spam', 'illegal', 'rights', 'security') then
      raise exception 'yg:validation:Elige qué norma incumple.';
    end if;
    if r.target_owner_id is not null and not r.content_removed and r.target_type <> 'profile' then
      insert into moderation_removals (report_id, owner_id, content_kind, content_id, reason, data, storage_path, rule)
      values (r.id, r.target_owner_id, r.target_type, r.target_id, r.reason, yg_removal_snapshot(r.target_type, r.target_id),
              case r.target_type
                when 'photo' then (select storage_path from photos where id = r.target_id)
                when 'group_post' then (select photo_path from group_posts where id = r.target_id)
              end, resolve_report.rule);
    end if;
    if r.target_type = 'status' then delete from posts where id = r.target_id;
    elsif r.target_type = 'photo' then delete from photos where id = r.target_id;
    elsif r.target_type = 'comment' then delete from comments where id = r.target_id;
    elsif r.target_type = 'wall_message' then delete from wall_messages where id = r.target_id;
    elsif r.target_type = 'message' then update messages set text = '', deleted_at = now() where id = r.target_id and deleted_at is null;
    elsif r.target_type = 'group_post' then delete from group_posts where id = r.target_id;
    elsif r.target_type = 'group_reply' then delete from group_replies where id = r.target_id;
    else raise exception 'yg:validation:Un perfil no se puede eliminar desde aquí.';
    end if;
    delete from notifications where target_id = r.target_id;
  end if;

  update reports set
    status = decision,
    resolved_by = me,
    resolved_at = now(),
    resolution_note = note,
    content_removed = content_removed or (remove_content and decision = 'resolved')
  where target_type = r.target_type and target_id = r.target_id and (id = target or status = 'pending');
end;
$$;
grant execute on function resolve_report(uuid, text, boolean, text, text) to authenticated;

create or replace function my_moderation_notices() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id,
      'content_kind', r.content_kind,
      'reason', r.reason,
      'rule', r.rule,
      'automated', r.automated,
      'removed_at', r.removed_at,
      'appeal_until', r.appeal_until,
      'can_appeal', r.appealed_at is null and r.appeal_until > now(),
      'appealed_at', r.appealed_at,
      'decision', r.decision,
      'restored', r.restored
    ) order by r.removed_at desc), '[]'::jsonb)
  from moderation_removals r where r.owner_id = yg_me() and r.notice_dismissed_at is null;
$$;

-- ---- Place groups: only counting in the total ---------------------------------------------------------

alter table group_members add column hidden boolean not null default false;

drop function if exists set_my_group_settings(uuid, text, text);
create or replace function set_my_group_settings(target uuid, profile_share text, notify text, hidden boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if profile_share not in ('basic', 'info', 'full') or notify not in ('all', 'mentions', 'none') then
    raise exception 'yg:validation:Opción no válida.';
  end if;
  update group_members m set
    profile_share = set_my_group_settings.profile_share,
    notify = set_my_group_settings.notify,
    -- Only in place groups (in user groups everyone knows who is in).
    hidden = coalesce(set_my_group_settings.hidden, false) and (select kind from groups where id = target) = 'place'
  where m.group_id = target and m.user_id = me;
  if not found then raise exception 'yg:not_found:No formas parte de este grupo.'; end if;
  return group_json(me, target);
end;
$$;
grant execute on function set_my_group_settings(uuid, text, text, boolean) to authenticated;

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
    'can_manage', yg_is_group_admin(gr.id, me),
    -- Your settings in this group.
    'my_settings', (select jsonb_build_object('profile_share', m.profile_share, 'notify', m.notify, 'hidden', m.hidden)
                    from group_members m where m.group_id = gr.id and m.user_id = me),
    'invited_by', (select person_summary(i.invited_by) from group_invites i where i.group_id = gr.id and i.user_id = me),
    'requested', exists (select 1 from group_join_requests r where r.group_id = gr.id and r.user_id = me),
    'request_count', case when x.my_role in ('owner', 'admin') then (select count(*) from group_join_requests r where r.group_id = gr.id) else 0 end,
    -- What the counters show, following your notices for this group.
    'new_posts', case when yg_group_notify(gr.id, me) = 'all' then yg_group_new_posts(me, gr.id) else 0 end,
    'mentions', case when yg_group_notify(gr.id, me) in ('all', 'mentions') then yg_group_mentions(me, gr.id) else 0 end,
    'last_post_at', case when x.my_role is not null then (select max(p.created_at) from group_posts p where p.group_id = gr.id) end,
    'expires_at', case when x.my_role = 'owner' and gr.kind = 'user' and gr.first_joined_at is null then gr.created_at + interval '7 days' end
  )
  from groups gr, lateral (select yg_group_role(gr.id, me) as my_role) x
  where gr.id = g;
$$;

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
      where m.group_id = target and (m.user_id = me or not is_blocked_between(me, m.user_id))
        -- Who chose to only count in the total is not listed (administrators always are).
        and (not m.hidden or m.user_id = me or m.role <> 'member')
    ), '[]'::jsonb) else '[]'::jsonb end,
    'requests', case when yg_is_group_admin(target, me) then coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(r.user_id), 'created_at', r.created_at) order by r.created_at)
      from group_join_requests r where r.group_id = target and not is_blocked_between(me, r.user_id)
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end;
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
        and (not m.hidden or m.user_id = me)
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
          where m.group_id = target and yg_local_day(m.joined_at) = page.day and (m.user_id = me or not is_blocked_between(me, m.user_id))
            and (not m.hidden or m.user_id = me)))
        else jsonb_build_object('kind', 'event', 'event', event_json(me, page.event_id), 'last_activity_at', page.last_at)
      end order by page.last_at desc)
    from page
  ), '[]'::jsonb);
end;
$$;

-- ---- Data export -----------------------------------------------------------------------------------

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

-- The terms explain the illegal content reports and the statement of reasons,
-- and the privacy policy the option of place groups: everyone accepts them again.
-- Must match LEGAL.version in src/config/app.js.
create or replace function yg_terms_version() returns text
language sql immutable as $$ select '2026-10-01'::text $$;
