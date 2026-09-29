-- "Eliminar mi cuenta" and "Descargar mis datos" (audit L02, L06).
--
-- Deletion: the app first removes the person's files from Storage (only the
-- Storage API deletes the files themselves); this function refuses while any
-- remain, so no file is left orphaned. Then it deletes the auth user and every
-- row follows by ON DELETE CASCADE.

-- Hook for legal retention holds. Nothing is retained today: if a documented
-- reason appears (e.g. a court order), it goes here and can stop or narrow
-- the deletion.
create or replace function yg_account_deletion_holds(person uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  return;
end;
$$;

create or replace function delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  remaining int;
begin
  select count(*) into remaining from storage.objects
  where bucket_id in ('photos', 'avatars', 'covers') and (storage.foldername(name))[1] = me::text;
  if remaining > 0 then
    raise exception 'yg:conflict:Todavía quedan archivos tuyos. Vuelve a intentarlo.';
  end if;

  perform yg_account_deletion_holds(me);

  -- Conversations lose their meaning without one of the two people: they go
  -- for both (the other person's messages in them too).
  delete from conversations c
  where exists (select 1 from conversation_members m where m.conversation_id = c.id and m.user_id = me);
  -- Invitations that brought this person in hold their email.
  delete from invitations where used_by = me;
  delete from notifications where actor_id = me or user_id = me;

  delete from auth.users where id = me;
end;
$$;

-- Everything YOUNGrr holds about the caller, as JSON. Other people appear only
-- as a name when they are part of the caller's own data (friends, conversation
-- partner); their content is not included (e.g. messages received: only counted).
create or replace function export_my_data() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
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
        'adult_confirmed_at', p.adult_confirmed_at
      ) from profiles p, me where p.id = me.id
    ),
    'settings', (select to_jsonb(s) - 'user_id' from user_settings s, me where s.user_id = me.id),
    'status', (select jsonb_build_object('text', po.text, 'created_at', po.created_at) from posts po, me where po.author_id = me.id and po.kind = 'status'),
    'albums', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'description', a.description, 'kind', a.kind, 'created_at', a.created_at) order by a.created_at)
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
    'messages_sent', coalesce((select jsonb_agg(jsonb_build_object(
        'to', (select p.first_name || ' ' || p.last_name from conversation_members cm join profiles p on p.id = cm.user_id
               where cm.conversation_id = m.conversation_id and cm.user_id <> me.id limit 1),
        'text', m.text, 'deleted', m.deleted_at is not null, 'created_at', m.created_at) order by m.created_at)
      from messages m, me where m.sender_id = me.id), '[]'::jsonb),
    'messages_received_count', (select count(*) from messages m join conversation_members cm on cm.conversation_id = m.conversation_id, me
      where cm.user_id = me.id and m.sender_id <> me.id),
    'invitations_sent', coalesce((select jsonb_agg(jsonb_build_object('email', i.email, 'created_at', i.created_at, 'expires_at', i.expires_at, 'used', i.used_by is not null))
      from invitations i, me where i.inviter_id = me.id), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('about', r.target_type, 'reason', r.reason, 'status', r.status, 'created_at', r.created_at))
      from reports r, me where r.reporter_id = me.id), '[]'::jsonb)
  );
$$;

grant execute on function delete_my_account() to authenticated;
grant execute on function export_my_data() to authenticated;
