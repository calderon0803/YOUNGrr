-- Private messages between friends: one conversation per pair of people.

create or replace function start_conversation(other uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  conv uuid;
begin
  if not exists (select 1 from profiles where id = other) then raise exception 'yg:not_found:Esta persona ya no está en YOUNGrr.'; end if;
  select cm1.conversation_id into conv
  from conversation_members cm1
  join conversation_members cm2 on cm2.conversation_id = cm1.conversation_id
  where cm1.user_id = me and cm2.user_id = other
  limit 1;
  if conv is not null then return conv; end if;
  if not are_friends(me, other) then raise exception 'yg:forbidden:Solo puedes escribir a tus amigos.'; end if;
  insert into conversations default values returning id into conv;
  insert into conversation_members (conversation_id, user_id, last_read_at) values (conv, me, now()), (conv, other, null);
  return conv;
end;
$$;

create or replace function message_json(m messages) returns jsonb
language sql immutable as $$
  select jsonb_build_object('id', m.id, 'conversation_id', m.conversation_id, 'sender_id', m.sender_id, 'text', m.text, 'created_at', m.created_at);
$$;

create or replace function yg_unread_in(me uuid, conv uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int
  from messages m
  join conversation_members cm on cm.conversation_id = m.conversation_id and cm.user_id = me
  where m.conversation_id = conv and m.sender_id <> me and (cm.last_read_at is null or m.created_at > cm.last_read_at);
$$;

create or replace function conversation_json(me uuid, conv uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', c.id,
    'other', (select person_summary(cm.user_id) from conversation_members cm where cm.conversation_id = c.id and cm.user_id <> me limit 1),
    'last_message', (select message_json(m) from messages m where m.conversation_id = c.id order by m.created_at desc limit 1),
    'unread_count', yg_unread_in(me, c.id),
    'updated_at', c.updated_at
  )
  from conversations c where c.id = conv;
$$;

create or replace function yg_check_member(me uuid, conv uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from conversations where id = conv) then raise exception 'yg:not_found:Esta conversación no existe.'; end if;
  if not is_conversation_member(conv, me) then raise exception 'yg:forbidden:No formas parte de esta conversación.'; end if;
end;
$$;

-- Conversations with at least one message, latest first.
create or replace function list_conversations() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(conversation_json(yg_me(), c.id) order by c.updated_at desc), '[]'::jsonb)
  from conversations c
  where is_conversation_member(c.id, yg_me()) and exists (select 1 from messages m where m.conversation_id = c.id);
$$;

create or replace function get_conversation(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_check_member(me, target);
  return jsonb_build_object(
    'conversation', conversation_json(me, target),
    'messages', coalesce((select jsonb_agg(message_json(m) order by m.created_at) from messages m where m.conversation_id = target), '[]'::jsonb)
  );
end;
$$;

create or replace function send_message(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  msg messages;
begin
  perform yg_check_member(me, target);
  body := trim(coalesce(body, ''));
  if body = '' then raise exception 'yg:validation:El mensaje es obligatorio.'; end if;
  if char_length(body) > 2000 then raise exception 'yg:validation:El mensaje no puede superar los 2000 caracteres.'; end if;
  insert into messages (conversation_id, sender_id, text) values (target, me, body) returning * into msg;
  update conversation_members set last_read_at = msg.created_at where conversation_id = target and user_id = me;
  return message_json(msg);
end;
$$;

create or replace function mark_conversation_read(target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_check_member(me, target);
  update conversation_members set last_read_at = now() where conversation_id = target and user_id = me;
end;
$$;

-- Conversations with unread messages (not the number of messages).
create or replace function unread_conversations() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from conversation_members cm
  where cm.user_id = yg_me() and yg_unread_in(yg_me(), cm.conversation_id) > 0;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'message_json(messages)', 'yg_unread_in(uuid, uuid)', 'conversation_json(uuid, uuid)', 'yg_check_member(uuid, uuid)',
    'start_conversation(uuid)', 'list_conversations()', 'get_conversation(uuid)', 'send_message(uuid, text)',
    'mark_conversation_read(uuid)', 'unread_conversations()'
  ] loop
    execute format('revoke execute on function %s from public', fn);
    execute format('revoke execute on function %s from anon', fn);
  end loop;
  foreach fn in array array[
    'start_conversation(uuid)', 'list_conversations()', 'get_conversation(uuid)', 'send_message(uuid, text)',
    'mark_conversation_read(uuid)', 'unread_conversations()'
  ] loop
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;
