-- Blocking people. When A blocks B (or B blocks A), in both directions:
-- - their profiles only show the basics (name and photo), like a private one;
-- - no friendship, friend requests, messages, wall messages or comments;
-- - they do not appear in each other's search, suggestions or "Cerca de ti".
-- Blocking removes the friendship and pending requests. Only the blocker knows
-- (and can undo) the block; the other person is not told.

create table blocks (
  blocker_id uuid not null references profiles (id) on delete cascade,
  blocked_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table blocks enable row level security;
revoke all on table blocks from authenticated, anon;

create or replace function is_blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from blocks
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  );
$$;

-- Privacy helpers take blocks into account (policies and RPCs use them).
create or replace function can_view_profile(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select not is_blocked_between(viewer, owner)
     and allowed_by(viewer, owner, (select profile_visibility from user_settings where user_id = owner));
$$;

create or replace function can_send_request(sender uuid, target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select sender <> target
     and not are_friends(sender, target)
     and not is_blocked_between(sender, target)
     and case (select friend_requests from user_settings where user_id = target)
           when 'everyone' then true
           when 'friends_of_friends' then mutual_friends(sender, target) > 0
           else false
         end;
$$;

create or replace function block_user(target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if target = me then raise exception 'yg:validation:No puedes bloquearte a ti.'; end if;
  if not exists (select 1 from profiles where id = target) then raise exception 'yg:not_found:Esta persona no existe.'; end if;
  insert into blocks (blocker_id, blocked_id) values (me, target) on conflict do nothing;
  delete from friendships where (user_a, user_b) = (least(me, target), greatest(me, target));
  delete from friend_requests where status = 'pending' and ((from_id = me and to_id = target) or (from_id = target and to_id = me));
  delete from photo_owners where status = 'pending' and ((user_id = me and invited_by = target) or (user_id = target and invited_by = me));
  delete from notifications where (user_id = me and actor_id = target) or (user_id = target and actor_id = me);
end;
$$;

create or replace function unblock_user(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from blocks where blocker_id = yg_me() and blocked_id = target;
end;
$$;

-- The people you blocked (never who blocked you).
create or replace function list_blocked() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('person', person_summary(b.blocked_id), 'created_at', b.created_at) order by b.created_at desc), '[]'::jsonb)
  from blocks b where b.blocker_id = yg_me();
$$;

-- Search skips blocked people in both directions.
create or replace function search_people(q text, max_results int default 30) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id),
  found as (
    select p.id, mutual_friends(me.id, p.id) as mutual
    from profiles p, me
    where p.id <> me.id
      and not p.needs_setup
      and not is_blocked_between(me.id, p.id)
      and length(trim(q)) > 0
      and yg_fold(p.first_name || ' ' || p.last_name || ' ' || case when can_view_city(me.id, p.id) then p.city else '' end)
          like '%' || yg_fold(trim(q)) || '%'
    order by mutual desc, p.first_name
    limit least(max_results, 50)
  )
  select people_view(coalesce(array_agg(id), '{}')) from found;
$$;

-- No new conversations or messages between blocked people.
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
  where cm1.user_id = me and cm2.user_id = other
  limit 1;
  if conv is not null then return conv; end if;
  if not are_friends(me, other) then raise exception 'yg:forbidden:Solo puedes escribir a tus amigos.'; end if;
  insert into conversations default values returning id into conv;
  insert into conversation_members (conversation_id, user_id, last_read_at) values (conv, me, now()), (conv, other, null);
  return conv;
end;
$$;

create or replace function send_message(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  msg messages;
begin
  perform yg_check_member(me, target);
  if exists (
    select 1 from conversation_members cm
    where cm.conversation_id = target and cm.user_id <> me and is_blocked_between(me, cm.user_id)
  ) then
    raise exception 'yg:forbidden:No puedes escribir a esta persona.';
  end if;
  body := trim(coalesce(body, ''));
  if body = '' then raise exception 'yg:validation:El mensaje es obligatorio.'; end if;
  if char_length(body) > 2000 then raise exception 'yg:validation:El mensaje no puede superar los 2000 caracteres.'; end if;
  insert into messages (conversation_id, sender_id, text) values (target, me, body) returning * into msg;
  update conversation_members set last_read_at = msg.created_at where conversation_id = target and user_id = me;
  return message_json(msg);
end;
$$;

grant execute on function block_user(uuid) to authenticated;
grant execute on function unblock_user(uuid) to authenticated;
grant execute on function list_blocked() to authenticated;
