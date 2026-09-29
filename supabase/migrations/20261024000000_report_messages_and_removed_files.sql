-- Reports on private messages, and removed photos also lose their file.
--
-- A participant can report a message someone else sent them; the moderator
-- then sees the copy of that message (only that one). Removing it erases its
-- text for both people, as when the sender deletes it.
-- When a moderator removes a reported photo, the app deletes its file too:
-- moderators may delete (only) files of photos removed through a report.

alter table reports drop constraint if exists reports_target_type_check;
alter table reports add constraint reports_target_type_check
  check (target_type in ('status', 'photo', 'comment', 'wall_message', 'profile', 'message'));

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
  -- A reported status stops appearing for the reporter, as before.
  if kind = 'status' then
    insert into hidden_posts (user_id, post_id) values (me, target) on conflict do nothing;
  end if;
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
    when 'message' then exists (select 1 from messages where id = r.target_id and deleted_at is null)
  end;
$$;

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

create or replace function yg_can_delete_removed_photo(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select is_moderator()
    and exists (select 1 from reports r where r.snapshot ->> 'storage_path' = path and r.content_removed)
    and not exists (select 1 from photos ph where ph.storage_path = path);
$$;
grant execute on function yg_can_delete_removed_photo(text) to authenticated;

create policy "moderators delete removed photos" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and yg_can_delete_removed_photo(name));
