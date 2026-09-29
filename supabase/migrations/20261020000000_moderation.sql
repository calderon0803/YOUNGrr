-- Basic moderation (audit L04): reports can be filed on statuses, photos,
-- comments, wall messages and profiles; moderators review and resolve them.
-- Reports are never readable through the normal API: only moderators, through
-- the functions below. More moderators = more rows in `moderators`, e.g.
--   insert into moderators (user_id) select id from auth.users where email = '...';
-- (run in the SQL editor; not possible from the app).

create table moderators (
  user_id  uuid primary key references profiles (id) on delete cascade,
  added_at timestamptz not null default now()
);
alter table moderators enable row level security;
revoke all on table moderators from authenticated, anon;

-- Whether the caller is a moderator (used by policies and the app).
create or replace function is_moderator() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from moderators where user_id = auth.uid());
$$;
grant execute on function is_moderator() to authenticated;

-- ---- Reports ---------------------------------------------------------------------------
-- A copy of the reported content is kept with the report, so the evidence does
-- not disappear if the author deletes it. The reporter's identity goes away if
-- they delete their account; the report itself stays for moderation.

alter table reports alter column post_id drop not null;
alter table reports drop constraint if exists reports_post_id_fkey;
alter table reports add constraint reports_post_id_fkey foreign key (post_id) references posts (id) on delete set null;
alter table reports alter column reporter_id drop not null;
alter table reports drop constraint if exists reports_reporter_id_fkey;
alter table reports add constraint reports_reporter_id_fkey foreign key (reporter_id) references profiles (id) on delete set null;

alter table reports
  add column target_type text check (target_type in ('status', 'photo', 'comment', 'wall_message', 'profile')),
  add column target_id uuid,
  -- Whose content it is. Reports about someone's content go when their account is deleted.
  add column target_owner_id uuid references profiles (id) on delete cascade,
  add column snapshot jsonb not null default '{}'::jsonb,
  add column status text not null default 'pending' check (status in ('pending', 'resolved', 'dismissed')),
  add column resolved_by uuid references profiles (id) on delete set null,
  add column resolved_at timestamptz,
  add column resolution_note text not null default '' check (char_length(resolution_note) <= 500),
  add column content_removed boolean not null default false;

update reports r set
  target_type = 'status',
  target_id = r.post_id,
  target_owner_id = p.author_id,
  snapshot = jsonb_build_object('text', p.text, 'kind', p.kind)
from posts p where p.id = r.post_id;
update reports set target_type = 'status', target_id = coalesce(target_id, post_id) where target_type is null;
alter table reports alter column target_type set not null;
alter table reports alter column target_id set not null;
create index reports_status_created on reports (status, created_at desc);
-- One open report per person and content.
create unique index reports_one_pending on reports (reporter_id, target_type, target_id) where status = 'pending';

-- Files a report on something the caller can see. Returns nothing: the reporter
-- is not told anything about other reports.
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
  -- A reported status stops appearing for the reporter, as before.
  if kind = 'status' then
    insert into hidden_posts (user_id, post_id) values (me, target) on conflict do nothing;
  end if;
end;
$$;

-- Kept for the current app: reporting a status.
create or replace function report_post(target uuid, reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform report_content('status', target, reason);
end;
$$;

-- ---- For moderators only -------------------------------------------------------------

create or replace function yg_require_moderator() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_moderator() then raise exception 'yg:forbidden:No tienes acceso a la moderación.'; end if;
end;
$$;

create or replace function yg_report_content_exists(r reports) returns boolean
language sql stable security definer set search_path = public as $$
  select case r.target_type
    when 'status' then exists (select 1 from posts where id = r.target_id)
    when 'photo' then exists (select 1 from photos where id = r.target_id)
    when 'comment' then exists (select 1 from comments where id = r.target_id)
    when 'wall_message' then exists (select 1 from wall_messages where id = r.target_id)
    when 'profile' then exists (select 1 from profiles where id = r.target_id)
  end;
$$;

create or replace function list_reports(filter text default 'pending') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_require_moderator();
  if filter not in ('pending', 'resolved', 'dismissed', 'all') then raise exception 'yg:validation:Filtro no válido.'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id,
      'target_type', r.target_type,
      'target_id', r.target_id,
      'reason', r.reason,
      'created_at', r.created_at,
      'status', r.status,
      'snapshot', r.snapshot,
      'content_exists', yg_report_content_exists(r),
      'content_removed', r.content_removed,
      'reporter', case when r.reporter_id is null then null else person_summary(r.reporter_id) end,
      'target_owner', case when r.target_owner_id is null then null else person_summary(r.target_owner_id) end,
      'resolved_by', case when r.resolved_by is null then null else person_summary(r.resolved_by) end,
      'resolved_at', r.resolved_at,
      'resolution_note', r.resolution_note
    ) order by r.created_at desc)
    from (select * from reports where filter = 'all' or status = filter order by created_at desc limit 200) r
  ), '[]'::jsonb);
end;
$$;

-- Resolves or dismisses a report; optionally removes the reported content.
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
    if r.target_type = 'status' then delete from posts where id = r.target_id;
    elsif r.target_type = 'photo' then delete from photos where id = r.target_id;
    elsif r.target_type = 'comment' then delete from comments where id = r.target_id;
    elsif r.target_type = 'wall_message' then delete from wall_messages where id = r.target_id;
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

grant execute on function report_content(text, uuid, text) to authenticated;
grant execute on function list_reports(text) to authenticated;
grant execute on function resolve_report(uuid, text, boolean, text) to authenticated;

-- Moderators can also see the photo of a report (only files that were reported).
create or replace function yg_can_read_photo_file(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select split_part(path, '/', 1) = auth.uid()::text
    or exists (select 1 from photos ph where ph.storage_path = path and can_view_photo(auth.uid(), ph.id))
    or exists (
      select 1 from events e
      where e.image_path = path and (e.creator_id = auth.uid() or is_event_member(e.id, auth.uid()))
    )
    or (is_moderator() and exists (select 1 from reports r where r.snapshot ->> 'storage_path' = path));
$$;
