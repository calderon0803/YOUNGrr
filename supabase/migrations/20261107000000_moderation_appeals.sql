-- Removed content can be appealed. When a moderator removes something after a
-- report:
-- - it stops being visible to everyone, but a full copy (with its comments,
--   Grr, tags...) is kept apart in moderation_removals;
-- - its owner gets a notice in Inicio with what was removed and the reason of
--   the report (never who reported it), and 14 days to appeal from it;
-- - if a moderator accepts the appeal, the content goes back where it was; if
--   the appeal is rejected, or nobody appeals in time, it is deleted for good
--   (the copy is emptied and the photo file deleted).

create table moderation_removals (
  id                  uuid primary key default gen_random_uuid(),
  report_id           uuid references reports (id) on delete set null,
  owner_id            uuid not null references profiles (id) on delete cascade,
  content_kind        text not null check (content_kind in ('status', 'photo', 'comment', 'wall_message', 'message')),
  content_id          uuid not null,
  reason              text not null,
  -- Everything needed to put it back; emptied once the removal is final.
  data                jsonb,
  storage_path        text,
  file_deleted        boolean not null default false,
  removed_at          timestamptz not null default now(),
  appeal_until        timestamptz not null default now() + interval '14 days',
  appeal_text         text check (char_length(appeal_text) <= 500),
  appealed_at         timestamptz,
  decision            text check (decision in ('accepted', 'rejected')),
  restored            boolean,
  decided_by          uuid references profiles (id) on delete set null,
  decided_at          timestamptz,
  notice_dismissed_at timestamptz
);
create index moderation_removals_owner on moderation_removals (owner_id, removed_at desc);
alter table moderation_removals enable row level security;
revoke all on table moderation_removals from authenticated, anon;

-- Final: the appeal was rejected, or the time to appeal ran out without one.
create or replace function yg_removal_final(r moderation_removals) returns boolean
language sql stable as $$
  -- Never null: "not final" must be true while there is no decision yet.
  select coalesce(r.decision = 'rejected', false) or (r.appealed_at is null and r.appeal_until <= now());
$$;

-- Restoring re-inserts rows as the moderator: rate limits do not apply to it.
create or replace function yg_rate_limit(what text, max_per_minute int) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  total int;
begin
  -- System work (triggers, SQL editor) and restorations are not limited.
  if me is null or current_setting('yg.restoring', true) = 'on' then return; end if;
  insert into rate_limits (user_id, action, window_start, hits)
  values (me, what, date_trunc('minute', now()), 1)
  on conflict (user_id, action, window_start) do update set hits = rate_limits.hits + 1
  returning hits into total;
  if total > max_per_minute then
    raise exception 'yg:rate_limited:Vas demasiado rápido. Espera un minuto e inténtalo de nuevo.';
  end if;
  if random() < 0.02 then
    delete from rate_limits where window_start < now() - interval '1 hour';
  end if;
end;
$$;

-- Everything that goes with a piece of content, to put it back later.
create or replace function yg_removal_snapshot(kind text, target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case kind
    when 'status' then jsonb_build_object(
      'post', (select to_jsonb(p) from posts p where p.id = target),
      'comments', coalesce((select jsonb_agg(to_jsonb(c)) from comments c where c.post_id = target), '[]'::jsonb),
      'grrs', coalesce((select jsonb_agg(to_jsonb(g)) from grrs g where g.post_id = target), '[]'::jsonb))
    when 'photo' then jsonb_build_object(
      'photo', (select to_jsonb(ph) from photos ph where ph.id = target),
      'owners', coalesce((select jsonb_agg(to_jsonb(o)) from photo_owners o where o.photo_id = target), '[]'::jsonb),
      'tags', coalesce((select jsonb_agg(to_jsonb(t)) from photo_tags t where t.photo_id = target), '[]'::jsonb),
      'comments', coalesce((select jsonb_agg(to_jsonb(c)) from comments c where c.photo_id = target), '[]'::jsonb),
      'grrs', coalesce((select jsonb_agg(to_jsonb(g)) from grrs g where g.photo_id = target), '[]'::jsonb),
      'albums', coalesce((select jsonb_agg(to_jsonb(ap)) from album_photos ap where ap.photo_id = target), '[]'::jsonb),
      'covers', coalesce((select jsonb_agg(a.id) from albums a where a.cover_photo_id = target), '[]'::jsonb))
    when 'comment' then jsonb_build_object('comment', (select to_jsonb(c) from comments c where c.id = target))
    when 'wall_message' then jsonb_build_object('wall_message', (select to_jsonb(w) from wall_messages w where w.id = target))
    when 'message' then jsonb_build_object('text', (select m.text from messages m where m.id = target))
  end;
$$;

-- Puts the content back. False when it cannot be (e.g. the status was replaced
-- by a newer one, or what it belonged to no longer exists).
create or replace function yg_restore_removal(r moderation_removals) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare
  d jsonb := r.data;
begin
  if d is null then return false; end if;
  perform set_config('yg.restoring', 'on', true);
  begin
    if r.content_kind = 'status' then
      insert into posts select * from jsonb_populate_record(null::posts, d -> 'post');
      insert into comments select * from jsonb_populate_recordset(null::comments, d -> 'comments');
      insert into grrs select * from jsonb_populate_recordset(null::grrs, d -> 'grrs');
    elsif r.content_kind = 'photo' then
      insert into photos select * from jsonb_populate_record(null::photos, d -> 'photo');
      insert into photo_owners select * from jsonb_populate_recordset(null::photo_owners, d -> 'owners') on conflict do nothing;
      insert into photo_tags select * from jsonb_populate_recordset(null::photo_tags, d -> 'tags') on conflict do nothing;
      insert into comments select * from jsonb_populate_recordset(null::comments, d -> 'comments') on conflict do nothing;
      insert into grrs select * from jsonb_populate_recordset(null::grrs, d -> 'grrs') on conflict do nothing;
      insert into album_photos select * from jsonb_populate_recordset(null::album_photos, d -> 'albums') on conflict do nothing;
      update albums set cover_photo_id = r.content_id
      where id in (select (x #>> '{}')::uuid from jsonb_array_elements(d -> 'covers') x) and cover_photo_id is null;
    elsif r.content_kind = 'comment' then
      insert into comments select * from jsonb_populate_record(null::comments, d -> 'comment');
    elsif r.content_kind = 'wall_message' then
      insert into wall_messages select * from jsonb_populate_record(null::wall_messages, d -> 'wall_message');
    elsif r.content_kind = 'message' then
      update messages set text = d ->> 'text', deleted_at = null where id = r.content_id;
      if not found then raise exception 'gone'; end if;
    end if;
  exception when others then
    perform set_config('yg.restoring', 'off', true);
    return false;
  end;
  perform set_config('yg.restoring', 'off', true);
  return true;
end;
$$;

-- ---- Removing after a report keeps a copy and tells the owner ------------------------------

create or replace function resolve_report(target uuid, decision text, remove_content boolean default false, note text default '')
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
    -- A copy is kept apart for the appeal, and its owner gets a notice (once).
    if r.target_owner_id is not null and not r.content_removed and r.target_type <> 'profile' then
      insert into moderation_removals (report_id, owner_id, content_kind, content_id, reason, data, storage_path)
      values (r.id, r.target_owner_id, r.target_type, r.target_id, r.reason, yg_removal_snapshot(r.target_type, r.target_id),
              case when r.target_type = 'photo' then (select storage_path from photos where id = r.target_id) end);
    end if;
    if r.target_type = 'status' then delete from posts where id = r.target_id;
    elsif r.target_type = 'photo' then delete from photos where id = r.target_id;
    elsif r.target_type = 'comment' then delete from comments where id = r.target_id;
    elsif r.target_type = 'wall_message' then delete from wall_messages where id = r.target_id;
    elsif r.target_type = 'message' then update messages set text = '', deleted_at = now() where id = r.target_id and deleted_at is null;
    else raise exception 'yg:validation:Un perfil no se puede eliminar desde aquí.';
    end if;
    delete from notifications where target_id = r.target_id;
  end if;

  -- Every open report on the same content gets the same decision.
  update reports set
    status = decision,
    resolved_by = me,
    resolved_at = now(),
    resolution_note = note,
    content_removed = content_removed or (remove_content and decision = 'resolved')
  where target_type = r.target_type and target_id = r.target_id and (id = target or status = 'pending');
end;
$$;

-- ---- The owner: notices and appeals ----------------------------------------------------------

-- Your notices: removals not dismissed yet, with the state of the appeal.
create or replace function my_moderation_notices() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id,
      'content_kind', r.content_kind,
      'reason', r.reason,
      'removed_at', r.removed_at,
      'appeal_until', r.appeal_until,
      'can_appeal', r.appealed_at is null and r.appeal_until > now(),
      'appealed_at', r.appealed_at,
      'decision', r.decision,
      'restored', r.restored
    ) order by r.removed_at desc), '[]'::jsonb)
  from moderation_removals r where r.owner_id = yg_me() and r.notice_dismissed_at is null;
$$;

-- Closing a notice while an appeal is waiting is not possible (its answer
-- would be lost); closing it before appealing gives up the appeal.
create or replace function dismiss_moderation_notice(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update moderation_removals set notice_dismissed_at = now()
  where id = target and owner_id = yg_me() and not (appealed_at is not null and decision is null);
end;
$$;

create or replace function appeal_removal(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  body := trim(coalesce(body, ''));
  if char_length(body) > 500 then raise exception 'yg:validation:La explicación no puede superar los 500 caracteres.'; end if;
  update moderation_removals set appeal_text = body, appealed_at = now()
  where id = target and owner_id = me and appealed_at is null and appeal_until > now() and notice_dismissed_at is null;
  if not found then raise exception 'yg:conflict:Ya no se puede apelar esta decisión.'; end if;
  return my_moderation_notices();
end;
$$;

-- ---- Moderators: appeals ------------------------------------------------------------------------

create or replace function list_appeals() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_require_moderator();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'content_kind', r.content_kind,
        'reason', r.reason,
        'owner', person_summary(r.owner_id),
        'removed_at', r.removed_at,
        'appeal_text', r.appeal_text,
        'appealed_at', r.appealed_at,
        'text', coalesce(
          r.data #>> '{post,text}', r.data #>> '{photo,caption}', r.data #>> '{comment,text}',
          r.data #>> '{wall_message,text}', r.data ->> 'text'),
        'storage_path', r.storage_path
      ) order by r.appealed_at)
    from moderation_removals r where r.appealed_at is not null and r.decision is null
  ), '[]'::jsonb);
end;
$$;

-- accept: the content goes back (if it can) and the owner is told.
create or replace function resolve_appeal(target uuid, accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  r moderation_removals;
  back boolean := false;
begin
  perform yg_require_moderator();
  select * into r from moderation_removals where id = target and appealed_at is not null and decision is null;
  if r.id is null then raise exception 'yg:not_found:Esta apelación ya no está pendiente.'; end if;
  if accept then back := yg_restore_removal(r); end if;
  update moderation_removals set
    decision = case when accept then 'accepted' else 'rejected' end,
    restored = case when accept then back end,
    decided_by = me,
    decided_at = now(),
    -- The owner sees the answer as a new notice.
    notice_dismissed_at = null,
    data = case when accept and back then null else data end
  where id = target;
  if accept and back then
    update reports set content_removed = false where id = r.report_id;
  end if;
  return jsonb_build_object('restored', back);
end;
$$;

-- ---- Final removals: files and clean-up ------------------------------------------------------

-- The photo is only deleted for good once the removal is final.
create or replace function yg_can_delete_removed_photo(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select is_moderator()
    and exists (select 1 from reports r where r.snapshot ->> 'storage_path' = path and r.content_removed)
    and not exists (select 1 from photos ph where ph.storage_path = path)
    and not exists (select 1 from moderation_removals m where m.storage_path = path and not yg_removal_final(m));
$$;

-- Photo files whose removal is final and still exist; the moderation page
-- deletes them (Storage files cannot be deleted from SQL).
create or replace function moderation_files_to_delete() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_require_moderator();
  return coalesce((
    select jsonb_agg(m.storage_path)
    from moderation_removals m
    where m.storage_path is not null and not m.file_deleted and yg_removal_final(m)
  ), '[]'::jsonb);
end;
$$;

create or replace function mark_moderation_files_deleted(paths text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform yg_require_moderator();
  update moderation_removals m set file_deleted = true
  where m.storage_path = any(paths) and yg_removal_final(m);
end;
$$;

-- Every night: final removals lose their copy; closed notices of final
-- removals whose file is gone disappear.
create or replace function yg_purge_removals() returns int
language plpgsql volatile security definer set search_path = public as $$
declare
  n int;
begin
  update moderation_removals m set data = null where m.data is not null and yg_removal_final(m);
  delete from moderation_removals m
  where (yg_removal_final(m) or m.decision = 'accepted')
    and m.notice_dismissed_at is not null
    and (m.storage_path is null or m.file_deleted or m.decision = 'accepted');
  get diagnostics n = row_count;
  return n;
end;
$$;

grant execute on function my_moderation_notices() to authenticated;
grant execute on function dismiss_moderation_notice(uuid) to authenticated;
grant execute on function appeal_removal(uuid, text) to authenticated;
grant execute on function list_appeals() to authenticated;
grant execute on function resolve_appeal(uuid, boolean) to authenticated;
grant execute on function moderation_files_to_delete() to authenticated;
grant execute on function mark_moderation_files_deleted(text[]) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('youngrr-removals', '45 3 * * *', 'select public.yg_purge_removals()');
  end if;
exception when others then
  raise notice 'pg_cron no disponible: programa yg_purge_removals() a mano (%).', sqlerrm;
end;
$$;

-- Removed photos that can still be appealed are not orphans.
create or replace function admin_storage_orphans() returns table (bucket text, path text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select o.bucket_id, o.name, o.created_at
  from storage.objects o
  where o.bucket_id in ('photos', 'avatars', 'covers')
    and o.created_at < now() - interval '1 day'
    and not (
      (o.bucket_id = 'photos' and (
        exists (select 1 from photos ph where ph.storage_path = o.name)
        or exists (select 1 from events e where e.image_path = o.name)
        or exists (select 1 from reports r where r.snapshot ->> 'storage_path' = o.name and r.status = 'pending')
        -- Removed photos that can still be appealed.
        or exists (select 1 from moderation_removals m where m.storage_path = o.name and not yg_removal_final(m))))
      or (o.bucket_id = 'avatars' and exists (select 1 from profiles p where p.avatar_url like '%/avatars/' || o.name))
      or (o.bucket_id = 'covers' and exists (select 1 from profiles p where p.cover_path = o.name))
    )
  order by o.created_at;
$$;

-- ---- Data export: removals of your content ---------------------------------------------------

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
    'content_removed', coalesce((select jsonb_agg(jsonb_build_object('content_kind', m.content_kind, 'reason', m.reason, 'removed_at', m.removed_at,
        'appeal_text', m.appeal_text, 'appealed_at', m.appealed_at, 'decision', m.decision) order by m.removed_at)
      from moderation_removals m, me where m.owner_id = me.id), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('about', r.target_type, 'reason', r.reason, 'status', r.status, 'created_at', r.created_at))
      from reports r, me where r.reporter_id = me.id), '[]'::jsonb)
  );
$$;
