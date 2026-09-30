-- Reports reach moderation only when enough different people report the same
-- content: 10 (app_settings.report_threshold), or 1 for private messages (only
-- two people can see them). Reporting hides nothing from anybody. Moderation
-- shows each piece of content once, with how many reports and which reasons.
-- Reports that never reach the minimum are deleted after 90 days.
-- Moderators get a count of what is waiting (see moderation_pending_count).

insert into app_settings (key, value) values ('report_threshold', '10') on conflict (key) do nothing;

insert into retention_settings (key, days, note)
values ('reports_below_threshold', 90, 'Reportes que no llegan al mínimo para ir a moderación: 90 días.')
on conflict (key) do nothing;

create or replace function yg_report_threshold(kind text) returns int
language sql stable security definer set search_path = public as $$
  select case when kind = 'message' then 1
    else coalesce((select value::int from app_settings where key = 'report_threshold'), 10) end;
$$;

-- One entry per reported piece of content. The id is its latest report (the
-- one resolve_report gets); the decision applies to all its open reports.
create or replace function list_reports(filter text default 'pending') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_require_moderator();
  if filter not in ('pending', 'resolved', 'dismissed', 'all') then raise exception 'yg:validation:Filtro no válido.'; end if;
  return coalesce((
    select jsonb_agg(g.item order by g.last_at desc)
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
        max(r.created_at) as last_at
      from reports r
      where filter = 'all' or r.status = filter
      group by r.target_type, r.target_id
      having filter <> 'pending' or count(*) >= yg_report_threshold(r.target_type)
      order by max(r.created_at) desc
      limit 200
    ) g
  ), '[]'::jsonb);
end;
$$;

-- What waits for moderators: content with enough reports, and appeals.
create or replace function moderation_pending_count() returns int
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_require_moderator();
  return (
    select count(*) from (
      select 1 from reports r where r.status = 'pending'
      group by r.target_type, r.target_id
      having count(*) >= yg_report_threshold(r.target_type)
    ) g
  ) + (select count(*) from moderation_removals where appealed_at is not null and decision is null);
end;
$$;

grant execute on function moderation_pending_count() to authenticated;

-- Reporting no longer hides the status from whoever reported it.
create or replace function report_content(kind text, target uuid, reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  owner uuid;
  copy jsonb;
begin
  reason := trim(coalesce(reason, ''));
  if reason = '' or char_length(reason) > 200 then raise exception 'yg:validation:Elige un motivo.'; end if;

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
    -- Only a participant can report a message, and only someone else's.
    select m.sender_id, jsonb_build_object('text', m.text) into owner, copy
    from messages m where m.id = target and m.deleted_at is null and is_conversation_member(m.conversation_id, me);
  elsif kind = 'profile' then
    select p.id, jsonb_build_object('name', p.first_name || ' ' || p.last_name, 'bio', p.bio, 'avatar_url', p.avatar_url) into owner, copy
    from profiles p where p.id = target;
  else
    raise exception 'yg:validation:Tipo de contenido no válido.';
  end if;

  if owner is null then raise exception 'yg:not_found:Este contenido ya no existe.'; end if;
  if owner = me then raise exception 'yg:validation:No puedes reportar tu propio contenido.'; end if;

  insert into reports (reporter_id, post_id, reason, target_type, target_id, target_owner_id, snapshot)
  values (me, case when kind = 'status' then target end, reason, kind, target, owner, copy)
  on conflict (reporter_id, target_type, target_id) where status = 'pending' do nothing;
end;
$$;

-- Retention: reports below the minimum go after 90 days.
create or replace function run_retention() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  result jsonb := '{}'::jsonb;
  n int;
begin
  delete from invitations
  where used_by is null and expires_at < now() - make_interval(days => yg_retention_days('invitations_expired'));
  get diagnostics n = row_count; result := result || jsonb_build_object('invitations', n);

  delete from notifications
  where (read_at is not null and read_at < now() - make_interval(days => yg_retention_days('notifications_read')))
     or (read_at is null and created_at < now() - make_interval(days => yg_retention_days('notifications_unread')));
  get diagnostics n = row_count; result := result || jsonb_build_object('notifications', n);

  delete from friend_requests
  where status in ('rejected', 'cancelled')
    and coalesce(responded_at, created_at) < now() - make_interval(days => yg_retention_days('friend_requests_closed'));
  get diagnostics n = row_count; result := result || jsonb_build_object('friend_requests', n);

  delete from photo_owners
  where status = 'rejected' and created_at < now() - make_interval(days => yg_retention_days('photo_owner_invites_closed'));
  get diagnostics n = row_count; result := result || jsonb_build_object('photo_owner_invites', n);

  delete from reports
  where status <> 'pending' and resolved_at < now() - make_interval(days => yg_retention_days('reports_closed'));
  get diagnostics n = row_count; result := result || jsonb_build_object('reports', n);

  -- Reports that never got enough others to reach moderation.
  delete from reports
  where status = 'pending' and created_at < now() - make_interval(days => yg_retention_days('reports_below_threshold'));
  get diagnostics n = row_count; result := result || jsonb_build_object('reports_below_threshold', n);

  -- Temporary passwords do not stay usable forever: the account is blocked
  -- until an administrator creates a new temporary password.
  update auth.users u set banned_until = 'infinity'
  from profiles p
  where p.id = u.id and p.must_change_password
    and u.created_at < now() - make_interval(days => yg_retention_days('temporary_password_days'))
    and (u.banned_until is null or u.banned_until < now());
  get diagnostics n = row_count; result := result || jsonb_build_object('temporary_accounts_blocked', n);

  return result;
end;
$$;

-- The terms and privacy policy now explain the minimum of reports: everyone
-- accepts them again. Must match LEGAL.version in src/config/app.js.
create or replace function yg_terms_version() returns text
language sql immutable as $$ select '2026-09-30.2'::text $$;

