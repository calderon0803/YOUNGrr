-- Privacy and notices of each group, mentions, group chat invitations and the
-- activity of a group.
--
-- - Friend privacy and group privacy are separate. For your friends only your
--   friend settings count; what you set in a group only affects its members who
--   are not your friends.
-- - In each group you choose what its members who are not your friends see of
--   you: your name and photo (default), also your information (town, studies,
--   work, birthday) or your whole profile. Everyone appears by name in the list
--   of people of every group.
-- - Notices, per group you created or joined: all the new posts, only when you
--   are mentioned, or nothing. Place groups only tell you about mentions.
-- - Mentions ("@Name Surname") in the Gallinero (posts and replies) and in group chats.
-- - The defaults for the groups you join, and who can invite you to groups, are
--   in your settings. Nobody is added to a group chat any more: you are invited
--   and join only if you accept.
-- - Each group has its news ("Novedades"): who joined, its new events and what
--   its members do (status, photos, shared achievements…), of the people you can see.

-- ---- Settings ------------------------------------------------------------------------------------

alter table user_settings
  add column group_profile_share text not null default 'basic' check (group_profile_share in ('basic', 'info', 'full')),
  add column group_notify text not null default 'all' check (group_notify in ('all', 'mentions', 'none')),
  add column group_invites text not null default 'friends' check (group_invites in ('friends', 'nobody'));
grant update (group_profile_share, group_notify, group_invites) on user_settings to authenticated;

alter table group_members
  add column profile_share text not null default 'basic' check (profile_share in ('basic', 'info', 'full')),
  add column notify text not null default 'all' check (notify in ('all', 'mentions', 'none'));

-- New members start with their defaults.
create or replace function on_group_member_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select s.group_profile_share, s.group_notify into new.profile_share, new.notify
  from user_settings s where s.user_id = new.user_id;
  new.profile_share := coalesce(new.profile_share, 'basic');
  new.notify := coalesce(new.notify, 'all');
  return new;
end;
$$;
create trigger group_member_defaults before insert on group_members for each row execute function on_group_member_defaults();

create or replace function set_my_group_settings(target uuid, profile_share text, notify text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if profile_share not in ('basic', 'info', 'full') or notify not in ('all', 'mentions', 'none') then
    raise exception 'yg:validation:Opción no válida.';
  end if;
  update group_members m set profile_share = set_my_group_settings.profile_share, notify = set_my_group_settings.notify
  where m.group_id = target and m.user_id = me;
  if not found then raise exception 'yg:not_found:No formas parte de este grupo.'; end if;
  return group_json(me, target);
end;
$$;

-- ---- What members who are not friends see of you -------------------------------------------------

-- 0 name and photo, 1 information, 2 whole profile: the most the owner shows
-- in a group both are in. Only for people who are not friends.
create or replace function yg_group_share(viewer uuid, owner uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(max(case o.profile_share when 'full' then 2 when 'info' then 1 else 0 end), 0)
  from group_members o join group_members v on v.group_id = o.group_id and v.user_id = viewer
  where o.user_id = owner and viewer <> owner and not are_friends(viewer, owner);
$$;

create or replace function can_view_profile(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select not is_blocked_between(viewer, owner)
     and (allowed_by(viewer, owner, (select profile_visibility from user_settings where user_id = owner))
          or yg_group_share(viewer, owner) = 2);
$$;

-- Information (town, studies, work, birthday): the whole profile, or a group sharing it.
create or replace function yg_can_view_info(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select can_view_profile(viewer, owner)
      or (not is_blocked_between(viewer, owner) and yg_group_share(viewer, owner) >= 1);
$$;

create or replace function can_view_city(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select (can_view_profile(viewer, owner)
          and allowed_by(viewer, owner, (select city_visibility from user_settings where user_id = owner)))
      or (not is_blocked_between(viewer, owner) and yg_group_share(viewer, owner) >= 1);
$$;

create or replace function profile_view(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p profiles;
  visible boolean;
  info boolean;
  latest posts;
begin
  select * into p from profiles where id = target;
  if not found then
    raise exception 'yg:not_found:Esta persona no existe o ha eliminado su cuenta.';
  end if;
  visible := can_view_profile(me, target);
  info := yg_can_view_info(me, target);
  if visible then
    select * into latest from posts where author_id = target and kind = 'status' limit 1;
  end if;
  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', p.id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'avatar_url', p.avatar_url,
      'cover_path', case when visible then p.cover_path end,
      'city', case when can_view_city(me, target) then p.city else '' end,
      'city_lat', null,
      'city_lng', null,
      'visit_count', case when me = target then p.visit_count end,
      'bio', case when info then p.bio else '' end,
      'birthday', case when me = target then p.birthday end,
      'birthday_day', case when info and p.birthday is not null then to_char(p.birthday, 'MM-DD') end,
      'studies', case when info then p.studies else '' end,
      'work', case when info then p.work else '' end,
      'created_at', p.created_at
    ),
    'friendship', friendship_status(me, target),
    'friends_count', (select count(*) from friendships where target in (user_a, user_b)),
    'mutual_friends', mutual_friends(me, target),
    'posts_count', case when visible then (select count(*) from posts where author_id = target) else 0 end,
    'photos_count', case when visible then (select count(*) from photos where owner_id = target) else 0 end,
    'can_view_profile', visible,
    'can_view_info', info,
    'can_send_request', friendship_status(me, target) = 'none' and can_send_request(me, target),
    'visits', case when me = target then p.visit_count end,
    'status', case when latest.id is null then null else jsonb_build_object('post_id', latest.id, 'text', latest.text, 'created_at', latest.created_at) end
  );
end;
$$;

-- ---- Everyone by name in the list of people ----------------------------------------------------

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
    ), '[]'::jsonb) else '[]'::jsonb end,
    'requests', case when yg_is_group_admin(target, me) then coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(r.user_id), 'created_at', r.created_at) order by r.created_at)
      from group_join_requests r where r.group_id = target and not is_blocked_between(me, r.user_id)
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end;
$$;

-- ---- Mentions ------------------------------------------------------------------------------------

alter table group_posts add column mentions uuid[] not null default '{}';
alter table group_replies add column mentions uuid[] not null default '{}';
alter table messages add column mentions uuid[] not null default '{}';

-- The people really mentioned: among `allowed`, not the author, without a block,
-- and whose "@Name Surname" is in the text (at most 10).
create or replace function yg_clean_mentions(me uuid, people uuid[], allowed uuid[], body text) returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(x.id), '{}') from (
    select distinct p.id from profiles p
    where p.id = any(coalesce(people, '{}')) and p.id = any(allowed) and p.id <> me
      and not is_blocked_between(me, p.id)
      and position(lower('@' || p.first_name || ' ' || p.last_name) in lower(body)) > 0
    limit 10
  ) x;
$$;

create or replace function yg_group_member_ids(g uuid) returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(user_id), '{}') from group_members where group_id = g;
$$;

-- Effective notices of a member: place groups only tell about mentions.
create or replace function yg_group_notify(g uuid, person uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when gr.kind = 'place' and m.notify = 'all' then 'mentions' else m.notify end
  from group_members m join groups gr on gr.id = m.group_id
  where m.group_id = g and m.user_id = person;
$$;

-- Mentions of a member after their last visit (posts and replies).
create or replace function yg_group_mentions(me uuid, g uuid) returns int
language sql stable security definer set search_path = public as $$
  select (
    select count(*) from group_posts p join group_members m on m.group_id = p.group_id and m.user_id = me
    where p.group_id = g and me = any(p.mentions) and p.created_at > m.last_seen_at and not is_blocked_between(me, p.author_id)
  ) + (
    select count(*) from group_replies r join group_posts p on p.id = r.post_id join group_members m on m.group_id = p.group_id and m.user_id = me
    where p.group_id = g and me = any(r.mentions) and r.created_at > m.last_seen_at and not is_blocked_between(me, r.author_id)
  );
$$;

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
    'my_settings', (select jsonb_build_object('profile_share', m.profile_share, 'notify', m.notify)
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

create or replace function group_post_json(me uuid, target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'group_id', p.group_id,
    'author', person_summary(p.author_id),
    'text', p.text,
    'mentions', (select coalesce(jsonb_agg(person_summary(u)), '[]'::jsonb) from unnest(p.mentions) u where exists (select 1 from profiles where id = u)),
    'photo_path', p.photo_path,
    'photo_width', p.photo_width,
    'photo_height', p.photo_height,
    'created_at', p.created_at,
    'grr_count', (select count(*) from group_post_grrs g where g.post_id = p.id),
    'has_grr', exists (select 1 from group_post_grrs g where g.post_id = p.id and g.user_id = me),
    'can_delete', p.author_id = me or yg_is_group_admin(p.group_id, me),
    'replies', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'author', person_summary(r.author_id), 'text', r.text, 'created_at', r.created_at,
          'mentions', (select coalesce(jsonb_agg(person_summary(u)), '[]'::jsonb) from unnest(r.mentions) u where exists (select 1 from profiles where id = u)),
          'can_delete', r.author_id = me or yg_is_group_admin(p.group_id, me)
        ) order by r.created_at)
      from group_replies r where r.post_id = p.id and (r.author_id = me or not is_blocked_between(me, r.author_id))
    ), '[]'::jsonb)
  )
  from group_posts p where p.id = target;
$$;

drop function if exists create_group_post(uuid, text, text, int, int);
create or replace function create_group_post(target uuid, body text, photo_path text default null, photo_width int default null,
  photo_height int default null, mentions uuid[] default '{}')
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  perform yg_require_group_member(me, target);
  body := trim(coalesce(body, ''));
  if char_length(body) > 280 then raise exception 'yg:validation:Una publicación no puede superar los 280 caracteres.'; end if;
  if body = '' and photo_path is null then raise exception 'yg:validation:Escribe algo o añade una foto.'; end if;
  perform yg_check_own_path(me, photo_path);
  insert into group_posts (group_id, author_id, text, photo_path, photo_width, photo_height, mentions)
  values (target, me, body, photo_path, photo_width, photo_height, yg_clean_mentions(me, create_group_post.mentions, yg_group_member_ids(target), body))
  returning id into new_id;
  update group_members set last_seen_at = now() where group_id = target and user_id = me;
  return group_post_json(me, new_id);
end;
$$;

drop function if exists add_group_reply(uuid, text);
create or replace function add_group_reply(target uuid, body text, mentions uuid[] default '{}') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p group_posts := yg_visible_group_post(me, target);
begin
  body := trim(coalesce(body, ''));
  if char_length(body) not between 1 and 280 then raise exception 'yg:validation:Escribe una respuesta (máximo 280 caracteres).'; end if;
  insert into group_replies (post_id, author_id, text, mentions)
  values (p.id, me, body, yg_clean_mentions(me, add_group_reply.mentions, yg_group_member_ids(p.group_id), body));
  return group_post_json(me, p.id);
end;
$$;

create or replace function message_json(m messages) returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'id', m.id, 'conversation_id', m.conversation_id, 'sender_id', m.sender_id,
    'text', m.text, 'created_at', m.created_at, 'deleted', m.deleted_at is not null,
    'mentions', case when m.deleted_at is null then to_jsonb(m.mentions) else '[]'::jsonb end
  );
$$;

drop function if exists send_message(uuid, text);
create or replace function send_message(target uuid, body text, mentions uuid[] default '{}') returns jsonb
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
  insert into messages (conversation_id, sender_id, text, mentions)
  values (target, me, body, case when (select kind from conversations where id = target) = 'group' then
    yg_clean_mentions(me, send_message.mentions, (select coalesce(array_agg(user_id), '{}') from conversation_members where conversation_id = target), body)
    else '{}' end)
  returning * into msg;
  update conversation_members set last_read_at = msg.created_at where conversation_id = target and user_id = me;
  update conversations set updated_at = msg.created_at where id = target;
  return message_json(msg);
end;
$$;

-- ---- Who can invite you to groups -----------------------------------------------------------------

create or replace function invite_to_group(target uuid, people uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  person uuid;
  fresh int := 0;
begin
  perform yg_require_group_member(me, target);
  perform yg_rate_limit('group_invite', 30);
  foreach person in array (select array(select distinct x from unnest(coalesce(people, '{}')) x where x <> me)) loop
    continue when yg_is_group_member(target, person) or exists (select 1 from group_invites where group_id = target and user_id = person);
    if not are_friends(me, person) or is_blocked_between(me, person) then
      raise exception 'yg:forbidden:Solo puedes invitar a tus amigos.';
    end if;
    if (select group_invites from user_settings where user_id = person) = 'nobody' then
      raise exception 'yg:forbidden:% no admite invitaciones a grupos.', (select first_name from profiles where id = person);
    end if;
    if exists (select 1 from group_join_requests where group_id = target and user_id = person) and yg_is_group_admin(target, me) then
      perform yg_join_group(target, person);
    else
      insert into group_invites (group_id, user_id, invited_by) values (target, person, me);
    end if;
    fresh := fresh + 1;
  end loop;
  if yg_group_member_count(target) + (select count(*) from group_invites where group_id = target) > 400 then
    raise exception 'yg:conflict:Hay demasiadas invitaciones pendientes en este grupo.';
  end if;
  return fresh;
end;
$$;

-- ---- Group chats: invitations instead of adding people ----------------------------------------------

create table conversation_invites (
  conversation_id uuid not null references conversations (id) on delete cascade,
  user_id         uuid not null references profiles (id) on delete cascade,
  invited_by      uuid references profiles (id) on delete cascade,
  created_at      timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create index conversation_invites_user on conversation_invites (user_id);
alter table conversation_invites enable row level security;
revoke all on table conversation_invites from authenticated, anon;

-- Invites friends without a block who are not in it yet; people and pending
-- invitations together, at most 20.
create or replace function yg_add_to_chat(me uuid, target uuid, people uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare
  person uuid;
  added int := 0;
begin
  foreach person in array (select array(select distinct x from unnest(coalesce(people, '{}')) x where x <> me)) loop
    continue when exists (select 1 from conversation_members where conversation_id = target and user_id = person)
               or exists (select 1 from conversation_invites where conversation_id = target and user_id = person);
    if not are_friends(me, person) then raise exception 'yg:forbidden:Solo puedes añadir a tus amigos.'; end if;
    if is_blocked_between(me, person) then raise exception 'yg:forbidden:No puedes añadir a esta persona.'; end if;
    insert into conversation_invites (conversation_id, user_id, invited_by) values (target, person, me);
    added := added + 1;
  end loop;
  if (select count(*) from conversation_members where conversation_id = target)
     + (select count(*) from conversation_invites where conversation_id = target) > 20 then
    raise exception 'yg:validation:Un grupo puede tener como mucho 20 personas.';
  end if;
  return added;
end;
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
    -- People invited who have not answered yet.
    'invited', (select coalesce(jsonb_agg(person_summary(ci.user_id) order by ci.created_at), '[]'::jsonb)
                from conversation_invites ci where ci.conversation_id = c.id),
    'last_message', (select message_json(m) from messages m
                     where m.conversation_id = c.id and yg_visible_message(me, c, m.sender_id)
                     order by m.created_at desc limit 1),
    'unread_count', yg_unread_in(me, c.id),
    'updated_at', c.updated_at
  )
  from conversations c where c.id = conv;
$$;

create or replace function remove_from_group_chat(target uuid, person uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_group_chat_of_creator(me, target);
  if person = me then raise exception 'yg:validation:Para irte, sal del grupo.'; end if;
  delete from conversation_members where conversation_id = target and user_id = person;
  delete from conversation_invites where conversation_id = target and user_id = person;
  return conversation_json(me, target);
end;
$$;

-- Chats you are invited to.
create or replace function chat_invitations() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select coalesce(jsonb_agg(jsonb_build_object(
      'conversation', conversation_json(me.id, ci.conversation_id),
      'invited_by', person_summary(ci.invited_by),
      'created_at', ci.created_at
    ) order by ci.created_at desc), '[]'::jsonb)
  from conversation_invites ci, me
  where ci.user_id = me.id and not is_blocked_between(me.id, ci.invited_by);
$$;

create or replace function answer_chat_invite(target uuid, accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  delete from conversation_invites where conversation_id = target and user_id = me;
  if not found then raise exception 'yg:not_found:Esta invitación ya no existe.'; end if;
  if accept then
    insert into conversation_members (conversation_id, user_id, last_read_at) values (target, me, null) on conflict do nothing;
    return conversation_json(me, target);
  end if;
  return null;
end;
$$;

-- ---- Counters in Inicio ---------------------------------------------------------------------------

create or replace function notification_state() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select jsonb_build_object(
    'settings', (select to_jsonb(s) from user_settings s where s.user_id = me.id),
    'conversation_ids', coalesce((
      select jsonb_agg(cm.conversation_id) from conversation_members cm
      where cm.user_id = me.id and yg_unread_in(me.id, cm.conversation_id) > 0
    ), '[]'::jsonb),
    'request_count', (select count(*) from friend_requests r where r.to_id = me.id and r.status = 'pending'),
    'invitation_event_ids', coalesce((
      select jsonb_agg(m.event_id) from event_members m where m.user_id = me.id and m.status = 'pending'
    ), '[]'::jsonb),
    'share_photo_ids', coalesce((
      select jsonb_agg(o.photo_id) from photo_owners o where o.user_id = me.id and o.status = 'pending'
    ), '[]'::jsonb),
    'group_invite_ids', coalesce((
      select jsonb_agg(i.group_id) from group_invites i where i.user_id = me.id and not is_blocked_between(me.id, i.invited_by)
    ), '[]'::jsonb),
    'group_request_ids', coalesce((
      select jsonb_agg(r.group_id) from group_join_requests r
      where yg_is_group_admin(r.group_id, me.id) and not is_blocked_between(me.id, r.user_id)
    ), '[]'::jsonb),
    'group_notice_count', (select count(*) from group_notices n where n.user_id = me.id),
    -- One entry per mention, with its group.
    'group_mention_ids', coalesce((
      select jsonb_agg(x.group_id) from (
        select m.group_id, generate_series(1, yg_group_mentions(me.id, m.group_id)) as n
        from group_members m where m.user_id = me.id and yg_group_notify(m.group_id, me.id) <> 'none'
      ) x
    ), '[]'::jsonb),
    'chat_invite_ids', coalesce((
      select jsonb_agg(ci.conversation_id) from conversation_invites ci
      where ci.user_id = me.id and not is_blocked_between(me.id, ci.invited_by)
    ), '[]'::jsonb),
    'unread', coalesce((
      select jsonb_agg(jsonb_build_object('type', n.type, 'target_id', n.target_id) order by n.created_at desc)
      from notifications n where n.user_id = me.id and n.read_at is null
    ), '[]'::jsonb)
  )
  from me;
$$;

-- ---- A group's news ---------------------------------------------------------------------------------

-- Like the friends' news, for the members of a group you can see (friends, or
-- people who show you their whole profile in a group), plus who joined each
-- day and the group's new events. The Gallinero has its own tab.
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
    ),
    items as (
      select 'person' as kind, person, yg_local_day(at) as day, max(at) as last_at, null::uuid as event_id
      from person_events group by person, yg_local_day(at)
      union all
      select 'joined', null, yg_local_day(m.joined_at), max(m.joined_at), null
      from group_members m, since
      where m.group_id = target and m.joined_at >= since.at and (m.user_id = me or not is_blocked_between(me, m.user_id))
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
          where m.group_id = target and yg_local_day(m.joined_at) = page.day and (m.user_id = me or not is_blocked_between(me, m.user_id))))
        else jsonb_build_object('kind', 'event', 'event', event_json(me, page.event_id), 'last_activity_at', page.last_at)
      end order by page.last_at desc)
    from page
  ), '[]'::jsonb);
end;
$$;

-- ---- Data export: your settings in each group and chat invitations ------------------------------------

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
        'profile_share', gm.profile_share, 'notify', gm.notify) order by gm.joined_at)
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

grant execute on function set_my_group_settings(uuid, text, text) to authenticated;
grant execute on function create_group_post(uuid, text, text, int, int, uuid[]) to authenticated;
grant execute on function add_group_reply(uuid, text, uuid[]) to authenticated;
grant execute on function send_message(uuid, text, uuid[]) to authenticated;
grant execute on function chat_invitations() to authenticated;
grant execute on function answer_chat_invite(uuid, boolean) to authenticated;
grant execute on function group_activity(uuid, timestamptz, int) to authenticated;

-- The terms and privacy policy explain the privacy of each group: everyone
-- accepts them again. Must match LEGAL.version in src/config/app.js.
create or replace function yg_terms_version() returns text
language sql immutable as $$ select '2026-09-30.5'::text $$;
