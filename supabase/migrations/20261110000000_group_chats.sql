-- Group chats among friends. A conversation is either "direct" (two people,
-- as until now) or "group":
-- - its creator names it and picks friends (up to 20 people in all; they need
--   not be friends with each other), adds and removes people; anyone can leave;
-- - if the creator leaves or deletes their account, the oldest member takes over;
--   the chat goes away when nobody is left;
-- - nobody can be added by someone they have a block with; a later block keeps
--   both in the chat but each stops seeing the other's messages;
-- - deleting an account deletes that person's messages; the chat goes on;
-- - a message in a chat of more than 5 people reaches moderation with 2 reports.

alter table conversations add column kind text not null default 'direct' check (kind in ('direct', 'group'));
alter table conversations add column title text check (title is null or char_length(title) between 1 and 60);
alter table conversations add column created_by uuid references profiles (id) on delete set null;
alter table conversation_members add column joined_at timestamptz not null default now();

create trigger rate_limit_conversations before insert on conversations for each row execute function on_rate_limited_insert('conversation', '10');

-- Messages this person may see in a conversation: in groups, not those of
-- someone they have a block with.
create or replace function yg_visible_message(me uuid, conv conversations, sender uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select conv.kind = 'direct' or sender = me or not is_blocked_between(me, sender);
$$;

create or replace function yg_unread_in(me uuid, conv uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int
  from messages m
  join conversation_members cm on cm.conversation_id = m.conversation_id and cm.user_id = me
  join conversations c on c.id = m.conversation_id
  where m.conversation_id = conv and m.sender_id <> me and (cm.last_read_at is null or m.created_at > cm.last_read_at)
    and yg_visible_message(me, c, m.sender_id);
$$;

create or replace function conversation_json(me uuid, conv uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', c.id,
    'kind', c.kind,
    'title', c.title,
    'created_by', c.created_by,
    'other', case when c.kind = 'direct' then
      (select person_summary(cm.user_id) from conversation_members cm where cm.conversation_id = c.id and cm.user_id <> me limit 1) end,
    'members', (select coalesce(jsonb_agg(person_summary(cm.user_id) order by cm.joined_at), '[]'::jsonb)
                from conversation_members cm where cm.conversation_id = c.id),
    'last_message', (select message_json(m) from messages m
                     where m.conversation_id = c.id and yg_visible_message(me, c, m.sender_id)
                     order by m.created_at desc limit 1),
    'unread_count', yg_unread_in(me, c.id),
    'updated_at', c.updated_at
  )
  from conversations c where c.id = conv;
$$;

-- Group chats show even before their first message; direct ones need one.
create or replace function list_conversations() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(conversation_json(yg_me(), c.id) order by c.updated_at desc), '[]'::jsonb)
  from conversations c
  where is_conversation_member(c.id, yg_me())
    and (c.kind = 'group' or exists (select 1 from messages m where m.conversation_id = c.id));
$$;

create or replace function get_conversation(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  c conversations;
begin
  perform yg_check_member(me, target);
  select * into c from conversations where id = target;
  return jsonb_build_object(
    'conversation', conversation_json(me, target),
    'messages', coalesce((
      select jsonb_agg(message_json(m) order by m.created_at) from messages m
      where m.conversation_id = target and yg_visible_message(me, c, m.sender_id)
    ), '[]'::jsonb)
  );
end;
$$;

-- The one-to-one conversation with a friend (never a group one).
create or replace function start_conversation(other uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  conv uuid;
begin
  if not exists (select 1 from profiles where id = other) then raise exception 'yg:not_found:Esta persona ya no está en YOUNGrr.'; end if;
  if is_blocked_between(me, other) then raise exception 'yg:forbidden:No puedes escribir a esta persona.'; end if;
  select cm1.conversation_id into conv
  from conversation_members cm1
  join conversation_members cm2 on cm2.conversation_id = cm1.conversation_id
  join conversations c on c.id = cm1.conversation_id and c.kind = 'direct'
  where cm1.user_id = me and cm2.user_id = other
  limit 1;
  if conv is not null then return conv; end if;
  if not are_friends(me, other) then raise exception 'yg:forbidden:Solo puedes escribir a tus amigos.'; end if;
  insert into conversations default values returning id into conv;
  insert into conversation_members (conversation_id, user_id, last_read_at) values (conv, me, now()), (conv, other, null);
  return conv;
end;
$$;

-- In direct chats a block stops the conversation; in groups it only hides
-- each other's messages.
create or replace function send_message(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  msg messages;
begin
  perform yg_check_member(me, target);
  if exists (
    select 1 from conversations c join conversation_members cm on cm.conversation_id = c.id
    where c.id = target and c.kind = 'direct' and cm.user_id <> me and is_blocked_between(me, cm.user_id)
  ) then
    raise exception 'yg:forbidden:No puedes escribir a esta persona.';
  end if;
  body := trim(coalesce(body, ''));
  if body = '' then raise exception 'yg:validation:El mensaje es obligatorio.'; end if;
  if char_length(body) > 2000 then raise exception 'yg:validation:El mensaje no puede superar los 2000 caracteres.'; end if;
  insert into messages (conversation_id, sender_id, text) values (target, me, body) returning * into msg;
  update conversation_members set last_read_at = msg.created_at where conversation_id = target and user_id = me;
  update conversations set updated_at = msg.created_at where id = target;
  return message_json(msg);
end;
$$;

-- ---- Managing group chats ---------------------------------------------------------------------

create or replace function yg_group_chat_of_creator(me uuid, target uuid) returns conversations
language plpgsql stable security definer set search_path = public as $$
declare
  c conversations;
begin
  perform yg_check_member(me, target);
  select * into c from conversations where id = target;
  if c.kind <> 'group' then raise exception 'yg:validation:Esta conversación no es un grupo.'; end if;
  if c.created_by is distinct from me then raise exception 'yg:forbidden:Solo quien creó el grupo puede hacer esto.'; end if;
  return c;
end;
$$;

-- People who can be added by `me`: friends, without a block, not already in.
create or replace function yg_add_to_chat(me uuid, target uuid, people uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare
  person uuid;
  added int := 0;
begin
  foreach person in array (select array(select distinct x from unnest(coalesce(people, '{}')) x where x <> me)) loop
    continue when exists (select 1 from conversation_members where conversation_id = target and user_id = person);
    if not are_friends(me, person) then raise exception 'yg:forbidden:Solo puedes añadir a tus amigos.'; end if;
    if is_blocked_between(me, person) then raise exception 'yg:forbidden:No puedes añadir a esta persona.'; end if;
    insert into conversation_members (conversation_id, user_id, last_read_at) values (target, person, null);
    added := added + 1;
  end loop;
  if (select count(*) from conversation_members where conversation_id = target) > 20 then
    raise exception 'yg:validation:Un grupo puede tener como mucho 20 personas.';
  end if;
  return added;
end;
$$;

create or replace function create_group_chat(title text, people uuid[]) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  conv uuid;
begin
  title := trim(coalesce(title, ''));
  if char_length(title) not between 1 and 60 then raise exception 'yg:validation:Ponle un nombre al grupo (máximo 60 caracteres).'; end if;
  if (select count(distinct p) from unnest(coalesce(people, '{}')) p where p <> me) < 2 then
    raise exception 'yg:validation:Elige al menos a dos amigos para crear un grupo.';
  end if;
  insert into conversations (kind, title, created_by) values ('group', create_group_chat.title, me) returning id into conv;
  insert into conversation_members (conversation_id, user_id, last_read_at) values (conv, me, now());
  perform yg_add_to_chat(me, conv, people);
  return conv;
end;
$$;

create or replace function rename_group_chat(target uuid, title text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_group_chat_of_creator(me, target);
  title := trim(coalesce(title, ''));
  if char_length(title) not between 1 and 60 then raise exception 'yg:validation:Ponle un nombre al grupo (máximo 60 caracteres).'; end if;
  update conversations set title = rename_group_chat.title where id = target;
  return conversation_json(me, target);
end;
$$;

create or replace function add_to_group_chat(target uuid, people uuid[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_group_chat_of_creator(me, target);
  if coalesce(array_length(people, 1), 0) = 0 then raise exception 'yg:validation:Elige al menos a una persona.'; end if;
  perform yg_add_to_chat(me, target, people);
  return conversation_json(me, target);
end;
$$;

create or replace function remove_from_group_chat(target uuid, person uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_group_chat_of_creator(me, target);
  if person = me then raise exception 'yg:validation:Para irte, sal del grupo.'; end if;
  delete from conversation_members where conversation_id = target and user_id = person;
  return conversation_json(me, target);
end;
$$;

-- Leaving: the creator's role goes to the oldest member; empty chats go.
create or replace function yg_leave_group_chat(person uuid, target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from conversation_members where conversation_id = target and user_id = person;
  if not exists (select 1 from conversation_members where conversation_id = target) then
    delete from conversations where id = target;
  else
    update conversations set created_by = (
      select user_id from conversation_members where conversation_id = target order by joined_at, user_id limit 1
    ) where id = target and (created_by = person or created_by is null);
  end if;
end;
$$;

create or replace function leave_group_chat(target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_check_member(me, target);
  if (select kind from conversations where id = target) <> 'group' then raise exception 'yg:validation:Esta conversación no es un grupo.'; end if;
  perform yg_leave_group_chat(me, target);
end;
$$;

grant execute on function create_group_chat(text, uuid[]) to authenticated;
grant execute on function rename_group_chat(uuid, text) to authenticated;
grant execute on function add_to_group_chat(uuid, uuid[]) to authenticated;
grant execute on function remove_from_group_chat(uuid, uuid) to authenticated;
grant execute on function leave_group_chat(uuid) to authenticated;

-- ---- Reports: 2 in chats of more than 5 people --------------------------------------------------

create or replace function yg_report_threshold(kind text, target uuid) returns int
language sql stable security definer set search_path = public as $$
  select case
    when kind = 'message' then case when (
      select count(*) from conversation_members cm
      where cm.conversation_id = (select conversation_id from messages where id = target)
    ) > 5 then 2 else 1 end
    else coalesce((select value::int from app_settings where key = 'report_threshold'), 10)
  end;
$$;

-- ---- Deleting an account: direct chats go, group chats go on ------------------------------------

create or replace function delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me_setup();
  remaining int;
  conv uuid;
begin
  select count(*) into remaining from storage.objects
  where bucket_id in ('photos', 'avatars', 'covers') and (storage.foldername(name))[1] = me::text;
  if remaining > 0 then
    raise exception 'yg:conflict:Todavía quedan archivos tuyos. Vuelve a intentarlo.';
  end if;

  perform yg_account_deletion_holds(me);

  -- A direct conversation loses its meaning without one of the two people: it
  -- goes for both (the other person's messages in it too).
  delete from conversations c
  where c.kind = 'direct' and exists (select 1 from conversation_members m where m.conversation_id = c.id and m.user_id = me);
  -- Group chats go on without this person (their messages go with the account).
  for conv in select cm.conversation_id from conversation_members cm join conversations c on c.id = cm.conversation_id
              where cm.user_id = me and c.kind = 'group' loop
    perform yg_leave_group_chat(me, conv);
  end loop;
  -- Invitations that brought this person in hold their email.
  delete from invitations where used_by = me;
  delete from notifications where actor_id = me or user_id = me;

  delete from auth.users where id = me;
end;
$$;

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
      having filter <> 'pending' or count(*) >= yg_report_threshold(r.target_type, r.target_id)
      order by max(r.created_at) desc
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
      having count(*) >= yg_report_threshold(r.target_type, r.target_id)
    ) g
  ) + (select count(*) from moderation_removals where appealed_at is not null and decision is null);
end;
$$;

-- ---- Data export: group chats with their name -------------------------------------------------

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

-- The terms and privacy policy now explain group chats: everyone accepts them
-- again. Must match LEGAL.version in src/config/app.js.
create or replace function yg_terms_version() returns text
language sql immutable as $$ select '2026-09-30.3'::text $$;
