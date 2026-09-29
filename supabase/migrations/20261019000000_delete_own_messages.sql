-- Private messages: the sender can delete their own messages. The text is
-- erased for both people and the conversation shows "Mensaje eliminado", so
-- the thread stays coherent. Nobody can delete someone else's message.

alter table messages add column deleted_at timestamptz;
alter table messages drop constraint if exists messages_text_check;
alter table messages add constraint messages_text_check check (
  (deleted_at is null and char_length(text) between 1 and 2000) or (deleted_at is not null and text = '')
);

create or replace function message_json(m messages) returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'id', m.id, 'conversation_id', m.conversation_id, 'sender_id', m.sender_id,
    'text', m.text, 'created_at', m.created_at, 'deleted', m.deleted_at is not null
  );
$$;

create or replace function delete_message(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  msg messages;
begin
  select * into msg from messages where id = target;
  -- Same answer whether it does not exist or belongs to a conversation you are not in.
  if msg.id is null or not is_conversation_member(msg.conversation_id, me) then
    raise exception 'yg:not_found:Este mensaje ya no existe.';
  end if;
  if msg.sender_id <> me then raise exception 'yg:forbidden:Solo puedes eliminar tus mensajes.'; end if;
  if msg.deleted_at is null then
    update messages set text = '', deleted_at = now() where id = target returning * into msg;
  end if;
  return message_json(msg);
end;
$$;

grant execute on function delete_message(uuid) to authenticated;
