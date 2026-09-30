-- Groups of people, with their own board: the Gallinero.
--
-- - Anyone can create a group ("de usuarios"), up to 10 at a time. It is:
--   - closed ("cerrado"): anyone finds it by its name and asks to join; its
--     administrators accept or reject the requests;
--   - secret ("secreto"): only its members and the people invited know it exists.
--   What is inside (the Gallinero, its people, its events) is only for members.
-- - Roles: the owner ("propietario"), administrators and members. The owner
--   names administrators and can hand the group over; administrators accept
--   requests, edit the group, remove members and delete posts in the Gallinero.
--   When the owner leaves, the oldest administrator (or member) takes over; a
--   group left empty is deleted.
-- - Members invite their friends; the invited person accepts or declines.
-- - Up to 200 members. A group nobody joined in 7 days is deleted by itself and
--   its creator gets a notice.
-- - The Gallinero: posts of up to 280 characters with an optional photo, replies
--   and Grr. Blocks apply: you never see posts or replies of people you have a
--   block with. Reports: a post or reply reaches the moderators with the reports
--   of 30% of the members (at least 3, at most 10).
-- - Group events: any member creates them for the group; the members see them
--   and join by answering.
-- Groups of places (phase 4) will use kind = 'place'.

create table groups (
  id              uuid primary key default gen_random_uuid(),
  kind            text not null default 'user' check (kind in ('user', 'place')),
  privacy         text not null default 'closed' check (privacy in ('closed', 'secret')),
  name            text not null check (char_length(name) between 1 and 60),
  description     text not null default '' check (char_length(description) <= 500),
  created_by      uuid references profiles (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- When someone other than its creator joined for the first time.
  first_joined_at timestamptz
);
create index groups_created_by on groups (created_by);

create table group_members (
  group_id     uuid not null references groups (id) on delete cascade,
  user_id      uuid not null references profiles (id) on delete cascade,
  role         text not null default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at    timestamptz not null default now(),
  -- The Gallinero's posts after this are "new" for the member.
  last_seen_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user on group_members (user_id);
create unique index group_members_one_owner on group_members (group_id) where role = 'owner';

create table group_invites (
  group_id   uuid not null references groups (id) on delete cascade,
  user_id    uuid not null references profiles (id) on delete cascade,
  invited_by uuid references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_invites_user on group_invites (user_id);

create table group_join_requests (
  group_id   uuid not null references groups (id) on delete cascade,
  user_id    uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_join_requests_user on group_join_requests (user_id);

create table group_posts (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references groups (id) on delete cascade,
  author_id    uuid not null references profiles (id) on delete cascade,
  text         text not null default '' check (char_length(text) <= 280),
  photo_path   text check (photo_path is null or split_part(photo_path, '/', 1) = author_id::text),
  photo_width  int,
  photo_height int,
  created_at   timestamptz not null default now(),
  check (char_length(trim(text)) > 0 or photo_path is not null)
);
create index group_posts_group on group_posts (group_id, created_at desc);
create index group_posts_author on group_posts (author_id);
create unique index group_posts_photo_path_key on group_posts (photo_path) where photo_path is not null;

create table group_replies (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references group_posts (id) on delete cascade,
  author_id  uuid not null references profiles (id) on delete cascade,
  text       text not null check (char_length(text) between 1 and 280),
  created_at timestamptz not null default now()
);
create index group_replies_post on group_replies (post_id, created_at);
create index group_replies_author on group_replies (author_id);

create table group_post_grrs (
  post_id    uuid not null references group_posts (id) on delete cascade,
  user_id    uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index group_post_grrs_user on group_post_grrs (user_id);

-- "Your group X was deleted because nobody joined it in 7 days."
create table group_notices (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles (id) on delete cascade,
  group_name text not null,
  created_at timestamptz not null default now()
);
create index group_notices_user on group_notices (user_id);

-- Everything goes through the functions below.
alter table groups enable row level security;
alter table group_members enable row level security;
alter table group_invites enable row level security;
alter table group_join_requests enable row level security;
alter table group_posts enable row level security;
alter table group_replies enable row level security;
alter table group_post_grrs enable row level security;
alter table group_notices enable row level security;
revoke all on table groups, group_members, group_invites, group_join_requests, group_posts, group_replies, group_post_grrs, group_notices
  from authenticated, anon;

create trigger rate_limit_groups before insert on groups for each row execute function on_rate_limited_insert('group', '3');
create trigger rate_limit_group_posts before insert on group_posts for each row execute function on_rate_limited_insert('group_post', '10');
create trigger rate_limit_group_replies before insert on group_replies for each row execute function on_rate_limited_insert('group_reply', '20');

-- The first person who joins (besides the creator) keeps the group alive.
create or replace function on_group_member_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update groups set first_joined_at = now()
  where id = new.group_id and first_joined_at is null and created_by is distinct from new.user_id;
  return new;
end;
$$;
create trigger group_member_joined after insert on group_members for each row execute function on_group_member_insert();

-- Settings: a switch for the group counters in Inicio.
alter table user_settings add column notify_groups boolean not null default true;
grant update (notify_groups) on user_settings to authenticated;

-- ---- Helpers ---------------------------------------------------------------------------------

create or replace function yg_group_role(g uuid, person uuid) returns text
language sql stable security definer set search_path = public as $$
  select role from group_members where group_id = g and user_id = person;
$$;

create or replace function yg_is_group_member(g uuid, person uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = g and user_id = person);
$$;

create or replace function yg_is_group_admin(g uuid, person uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(yg_group_role(g, person) in ('owner', 'admin'), false);
$$;

-- Members and invited people see a group; closed groups are also seen by
-- everyone without a block with their owner.
create or replace function can_see_group(me uuid, g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from groups gr
    where gr.id = g
      and (
        yg_is_group_member(gr.id, me)
        or exists (select 1 from group_invites i where i.group_id = gr.id and i.user_id = me)
        or (
          gr.privacy = 'closed'
          and not exists (
            select 1 from group_members o
            where o.group_id = gr.id and o.role = 'owner' and is_blocked_between(me, o.user_id)
          )
        )
      )
  );
$$;

create or replace function yg_group_member_count(g uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from group_members where group_id = g;
$$;

-- New posts in the Gallinero for a member: after their last visit, not their
-- own and not of people they have a block with.
create or replace function yg_group_new_posts(me uuid, g uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int
  from group_posts p join group_members m on m.group_id = p.group_id and m.user_id = me
  where p.group_id = g and p.created_at > m.last_seen_at and p.author_id <> me
    and not is_blocked_between(me, p.author_id);
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
    'owner', (select person_summary(o.user_id) from group_members o where o.group_id = gr.id and o.role = 'owner'),
    'member_count', yg_group_member_count(gr.id),
    'my_role', x.my_role,
    'invited_by', (select person_summary(i.invited_by) from group_invites i where i.group_id = gr.id and i.user_id = me),
    'requested', exists (select 1 from group_join_requests r where r.group_id = gr.id and r.user_id = me),
    'request_count', case when x.my_role in ('owner', 'admin') then (select count(*) from group_join_requests r where r.group_id = gr.id) else 0 end,
    'new_posts', case when x.my_role is not null then yg_group_new_posts(me, gr.id) else 0 end,
    'last_post_at', case when x.my_role is not null then (select max(p.created_at) from group_posts p where p.group_id = gr.id) end,
    -- Only its owner sees when a group nobody joined will be deleted.
    'expires_at', case when x.my_role = 'owner' and gr.kind = 'user' and gr.first_joined_at is null then gr.created_at + interval '7 days' end
  )
  from groups gr, lateral (select yg_group_role(gr.id, me) as my_role) x
  where gr.id = g;
$$;

-- A group that exists and you can see, or an error.
create or replace function yg_visible_group(me uuid, g uuid) returns groups
language plpgsql stable security definer set search_path = public as $$
declare
  gr groups;
begin
  select * into gr from groups where id = g;
  if gr.id is null or not can_see_group(me, g) then raise exception 'yg:not_found:Este grupo no existe o no puedes verlo.'; end if;
  return gr;
end;
$$;

create or replace function yg_require_group_member(me uuid, g uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_visible_group(me, g);
  if not yg_is_group_member(g, me) then raise exception 'yg:forbidden:Solo las personas del grupo pueden hacer esto.'; end if;
end;
$$;

create or replace function yg_require_group_admin(me uuid, g uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  perform yg_require_group_member(me, g);
  if not yg_is_group_admin(g, me) then raise exception 'yg:forbidden:Solo quien administra el grupo puede hacer esto.'; end if;
end;
$$;

create or replace function yg_check_group(group_name text, about text) returns void
language plpgsql immutable as $$
begin
  if char_length(trim(coalesce(group_name, ''))) not between 1 and 60 then
    raise exception 'yg:validation:Ponle un nombre al grupo (máximo 60 caracteres).';
  end if;
  if char_length(trim(coalesce(about, ''))) > 500 then
    raise exception 'yg:validation:La descripción no puede superar los 500 caracteres.';
  end if;
end;
$$;

-- Adds a person as a member (from an invitation or an accepted request).
create or replace function yg_join_group(g uuid, person uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if yg_is_group_member(g, person) then return; end if;
  if yg_group_member_count(g) >= 200 then raise exception 'yg:conflict:Este grupo ya tiene 200 personas, el máximo.'; end if;
  insert into group_members (group_id, user_id, role) values (g, person, 'member');
  delete from group_invites where group_id = g and user_id = person;
  delete from group_join_requests where group_id = g and user_id = person;
end;
$$;

-- The owner's role goes to the oldest administrator, or else the oldest member;
-- a group left empty goes.
create or replace function yg_leave_group(person uuid, g uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  was text := yg_group_role(g, person);
  heir uuid;
begin
  if was is null then return; end if;
  delete from group_members where group_id = g and user_id = person;
  if not exists (select 1 from group_members where group_id = g) then
    delete from groups where id = g;
    return;
  end if;
  if was = 'owner' then
    select user_id into heir from group_members where group_id = g
    order by case role when 'admin' then 0 else 1 end, joined_at limit 1;
    update group_members set role = 'owner' where group_id = g and user_id = heir;
  end if;
end;
$$;

-- ---- Your groups, invitations and search ------------------------------------------------------

-- Your groups, the most recently active first.
create or replace function list_my_groups() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select coalesce(jsonb_agg(group_json(me.id, x.group_id) order by x.active desc), '[]'::jsonb)
  from me, lateral (
    select m.group_id, greatest(m.joined_at, coalesce((select max(p.created_at) from group_posts p where p.group_id = m.group_id), m.joined_at)) as active
    from group_members m where m.user_id = me.id
  ) x;
$$;

create or replace function group_invitations() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id)
  select coalesce(jsonb_agg(group_json(me.id, i.group_id) order by i.created_at desc), '[]'::jsonb)
  from me, group_invites i
  where i.user_id = me.id and not is_blocked_between(me.id, i.invited_by);
$$;

-- Closed groups by name or description (secret ones never show up).
create or replace function search_groups(q text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  me uuid := yg_me();
  pattern text := '%' || yg_fold(trim(coalesce(q, ''))) || '%';
begin
  if length(trim(coalesce(q, ''))) = 0 then return '[]'::jsonb; end if;
  perform yg_rate_limit('search', 40);
  return coalesce((
    select jsonb_agg(group_json(me, f.id) order by f.members desc, f.name)
    from (
      select gr.id, gr.name, yg_group_member_count(gr.id) as members
      from groups gr
      where (gr.privacy = 'closed' or yg_is_group_member(gr.id, me))
        and can_see_group(me, gr.id)
        and yg_fold(gr.name || ' ' || gr.description) like pattern
      order by members desc, gr.name
      limit 20
    ) f
  ), '[]'::jsonb);
end;
$$;

-- The group, and for its members its people (and pending requests for administrators).
create or replace function get_group(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
  inside boolean;
begin
  perform yg_visible_group(me, target);
  inside := yg_is_group_member(target, me);
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

-- ---- Creating and managing ------------------------------------------------------------------

create or replace function create_group(group_name text, about text default '', secret boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  perform yg_check_group(group_name, about);
  if (select count(*) from groups where created_by = me and kind = 'user') >= 10 then
    raise exception 'yg:conflict:Ya has creado 10 grupos, el máximo. Elimina alguno para crear otro.';
  end if;
  insert into groups (kind, privacy, name, description, created_by)
  values ('user', case when secret then 'secret' else 'closed' end, trim(group_name), trim(coalesce(about, '')), me)
  returning id into new_id;
  insert into group_members (group_id, user_id, role) values (new_id, me, 'owner');
  return group_json(me, new_id);
end;
$$;

create or replace function update_group(target uuid, group_name text, about text, secret boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_require_group_admin(me, target);
  perform yg_check_group(group_name, about);
  update groups set
    name = trim(group_name),
    description = trim(coalesce(about, '')),
    privacy = case when kind = 'user' then (case when secret then 'secret' else 'closed' end) else privacy end,
    updated_at = now()
  where id = target;
  return group_json(me, target);
end;
$$;

-- Only its owner deletes a group. Returns the photo files of your own posts,
-- for the app to delete them.
create or replace function delete_group(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  paths jsonb;
begin
  perform yg_require_group_member(me, target);
  if yg_group_role(target, me) <> 'owner' then raise exception 'yg:forbidden:Solo quien es propietario del grupo puede eliminarlo.'; end if;
  select coalesce(jsonb_agg(photo_path), '[]'::jsonb) into paths
  from group_posts where group_id = target and author_id = me and photo_path is not null;
  delete from groups where id = target;
  return paths;
end;
$$;

-- Members invite their friends. Returns how many were invited.
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
    -- Someone who asked to join and is invited is simply in.
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

create or replace function answer_group_invite(target uuid, accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not exists (select 1 from group_invites where group_id = target and user_id = me) then
    raise exception 'yg:not_found:Esta invitación ya no existe.';
  end if;
  if accept then perform yg_join_group(target, me);
  else delete from group_invites where group_id = target and user_id = me;
  end if;
  return case when accept then group_json(me, target) else null end;
end;
$$;

-- Closed groups: asking to join (when invited, you are simply in).
create or replace function request_to_join_group(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  gr groups := yg_visible_group(me, target);
begin
  if yg_is_group_member(target, me) then return group_json(me, target); end if;
  if exists (select 1 from group_invites where group_id = target and user_id = me) then
    perform yg_join_group(target, me);
  else
    if gr.privacy <> 'closed' then raise exception 'yg:forbidden:A este grupo solo se entra con invitación.'; end if;
    perform yg_rate_limit('group_request', 20);
    insert into group_join_requests (group_id, user_id) values (target, me) on conflict do nothing;
  end if;
  return group_json(me, target);
end;
$$;

create or replace function cancel_group_request(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  delete from group_join_requests where group_id = target and user_id = me;
  return case when can_see_group(me, target) then group_json(me, target) end;
end;
$$;

create or replace function answer_group_request(target uuid, person uuid, accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_require_group_admin(me, target);
  if not exists (select 1 from group_join_requests where group_id = target and user_id = person) then
    raise exception 'yg:not_found:Esta solicitud ya no existe.';
  end if;
  if accept then perform yg_join_group(target, person);
  else delete from group_join_requests where group_id = target and user_id = person;
  end if;
end;
$$;

create or replace function leave_group(target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  if not yg_is_group_member(target, me) then raise exception 'yg:not_found:No formas parte de este grupo.'; end if;
  perform yg_leave_group(me, target);
end;
$$;

-- Administrators remove members; only the owner removes administrators.
create or replace function remove_group_member(target uuid, person uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  their text := yg_group_role(target, person);
begin
  perform yg_require_group_admin(me, target);
  if person = me then raise exception 'yg:validation:Para irte, sal del grupo.'; end if;
  if their is null then raise exception 'yg:not_found:Esta persona ya no está en el grupo.'; end if;
  if their = 'owner' or (their = 'admin' and yg_group_role(target, me) <> 'owner') then
    raise exception 'yg:forbidden:No puedes quitar a esta persona.';
  end if;
  delete from group_members where group_id = target and user_id = person;
end;
$$;

-- The owner names administrators, takes the role back, or hands the group over
-- ('owner': they become an administrator).
create or replace function set_group_role(target uuid, person uuid, new_role text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_require_group_member(me, target);
  if yg_group_role(target, me) <> 'owner' then raise exception 'yg:forbidden:Solo quien es propietario del grupo puede cambiar los papeles.'; end if;
  if new_role not in ('owner', 'admin', 'member') then raise exception 'yg:validation:Papel no válido.'; end if;
  if person = me or not yg_is_group_member(target, person) then raise exception 'yg:validation:Elige a otra persona del grupo.'; end if;
  if new_role = 'owner' then
    update group_members set role = 'admin' where group_id = target and user_id = me;
  end if;
  update group_members set role = new_role where group_id = target and user_id = person;
end;
$$;

create or replace function mark_group_seen(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update group_members set last_seen_at = now() where group_id = target and user_id = yg_me();
end;
$$;

-- Notices about your groups deleted because nobody joined them.
create or replace function my_group_notices() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'group_name', n.group_name, 'created_at', n.created_at) order by n.created_at desc), '[]'::jsonb)
  from group_notices n where n.user_id = yg_me();
$$;

create or replace function dismiss_group_notice(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from group_notices where id = target and user_id = yg_me();
end;
$$;

-- ---- The Gallinero ----------------------------------------------------------------------------

create or replace function group_post_json(me uuid, target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'group_id', p.group_id,
    'author', person_summary(p.author_id),
    'text', p.text,
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
          'can_delete', r.author_id = me or yg_is_group_admin(p.group_id, me)
        ) order by r.created_at)
      from group_replies r where r.post_id = p.id and (r.author_id = me or not is_blocked_between(me, r.author_id))
    ), '[]'::jsonb)
  )
  from group_posts p where p.id = target;
$$;

-- Newest first, page by page.
create or replace function list_group_posts(target uuid, before timestamptz default null, page_size int default 10) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_require_group_member(me, target);
  return coalesce((
    select jsonb_agg(group_post_json(me, p.id) order by p.created_at desc)
    from (
      select p.id, p.created_at from group_posts p
      where p.group_id = target
        and (before is null or p.created_at < before)
        and (p.author_id = me or not is_blocked_between(me, p.author_id))
      order by p.created_at desc
      limit least(greatest(page_size, 1), 30)
    ) p
  ), '[]'::jsonb);
end;
$$;

create or replace function create_group_post(target uuid, body text, photo_path text default null, photo_width int default null, photo_height int default null)
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
  insert into group_posts (group_id, author_id, text, photo_path, photo_width, photo_height)
  values (target, me, body, photo_path, photo_width, photo_height)
  returning id into new_id;
  -- Writing counts as having seen what came before.
  update group_members set last_seen_at = now() where group_id = target and user_id = me;
  return group_post_json(me, new_id);
end;
$$;

-- The author or the group's administrators. Returns the photo file when it is
-- the caller's, for the app to delete it.
create or replace function delete_group_post(target uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p group_posts;
begin
  select * into p from group_posts where id = target;
  if p.id is null or not yg_is_group_member(p.group_id, me) then raise exception 'yg:not_found:Esta publicación ya no existe.'; end if;
  if p.author_id <> me and not yg_is_group_admin(p.group_id, me) then
    raise exception 'yg:forbidden:Solo quien la escribió o quien administra el grupo puede eliminarla.';
  end if;
  delete from group_posts where id = target;
  return case when p.author_id = me then p.photo_path end;
end;
$$;

-- The post a member can see (not of someone they have a block with), or an error.
create or replace function yg_visible_group_post(me uuid, target uuid) returns group_posts
language plpgsql stable security definer set search_path = public as $$
declare
  p group_posts;
begin
  select * into p from group_posts where id = target;
  if p.id is null or not yg_is_group_member(p.group_id, me) or (p.author_id <> me and is_blocked_between(me, p.author_id)) then
    raise exception 'yg:not_found:Esta publicación ya no existe.';
  end if;
  return p;
end;
$$;

create or replace function add_group_reply(target uuid, body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p group_posts := yg_visible_group_post(me, target);
begin
  body := trim(coalesce(body, ''));
  if char_length(body) not between 1 and 280 then raise exception 'yg:validation:Escribe una respuesta (máximo 280 caracteres).'; end if;
  insert into group_replies (post_id, author_id, text) values (p.id, me, body);
  return group_post_json(me, p.id);
end;
$$;

create or replace function delete_group_reply(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  r group_replies;
  g uuid;
begin
  select * into r from group_replies where id = target;
  select group_id into g from group_posts where id = r.post_id;
  if r.id is null or not yg_is_group_member(g, me) then raise exception 'yg:not_found:Esta respuesta ya no existe.'; end if;
  if r.author_id <> me and not yg_is_group_admin(g, me) then
    raise exception 'yg:forbidden:Solo quien la escribió o quien administra el grupo puede eliminarla.';
  end if;
  delete from group_replies where id = target;
  return group_post_json(me, r.post_id);
end;
$$;

create or replace function set_group_grr(target uuid, value boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  p group_posts := yg_visible_group_post(me, target);
begin
  if value then
    perform yg_rate_limit('grr', 60);
    insert into group_post_grrs (post_id, user_id) values (p.id, me) on conflict do nothing;
  else
    delete from group_post_grrs where post_id = p.id and user_id = me;
  end if;
  return group_post_json(me, p.id);
end;
$$;

-- Gallinero photos follow the group: only its members see them.
create or replace function yg_can_read_photo_file(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select split_part(path, '/', 1) = auth.uid()::text
    or exists (select 1 from photos ph where ph.storage_path = path and can_view_photo(auth.uid(), ph.id))
    or exists (select 1 from events e where e.image_path = path and can_see_event(auth.uid(), e.id))
    or exists (
      select 1 from group_posts p where p.photo_path = path
        and yg_is_group_member(p.group_id, auth.uid()) and not is_blocked_between(auth.uid(), p.author_id))
    or (is_moderator() and exists (select 1 from reports r where r.snapshot ->> 'storage_path' = path));
$$;

-- ---- Group events -----------------------------------------------------------------------------

alter table events add column group_id uuid references groups (id) on delete cascade;
create index events_group on events (group_id) where group_id is not null;

create or replace function can_see_event(me uuid, target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from events e
    where e.id = target
      and (
        e.creator_id = me
        or is_event_member(e.id, me)
        or (
          e.group_id is not null
          and yg_is_group_member(e.group_id, me)
          and not is_blocked_between(me, e.creator_id)
        )
        or (
          e.is_public
          and not is_blocked_between(me, e.creator_id)
          and (are_friends(me, e.creator_id) or mutual_friends(me, e.creator_id) > 0)
        )
      )
  );
$$;

create or replace function event_json(me uuid, target uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', e.id,
    'creator_id', e.creator_id,
    'title', e.title,
    'description', e.description,
    'image_path', e.image_path,
    'date', e.date,
    'time', to_char(e.time, 'HH24:MI'),
    'location', e.location,
    'is_public', e.is_public,
    'group', (select jsonb_build_object('id', g.id, 'name', g.name) from groups g where g.id = e.group_id),
    'created_at', e.created_at,
    'updated_at', e.updated_at,
    'creator', person_summary(e.creator_id),
    'is_creator', e.creator_id = me,
    'my_status', (select m.status from event_members m where m.event_id = e.id and m.user_id = me),
    'counts', jsonb_build_object(
      'going', (select count(*) from event_members m where m.event_id = e.id and m.status = 'going'),
      'maybe', (select count(*) from event_members m where m.event_id = e.id and m.status = 'maybe'),
      'declined', case when inside then (select count(*) from event_members m where m.event_id = e.id and m.status = 'declined') else 0 end,
      'pending', case when inside then (select count(*) from event_members m where m.event_id = e.id and m.status = 'pending') else 0 end
    ),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('person', person_summary(m.user_id), 'status', m.status)
        order by case m.status when 'going' then 0 when 'maybe' then 1 when 'pending' then 2 else 3 end)
      from event_members m
      where m.event_id = e.id
        and (inside or m.status in ('going', 'maybe'))
        and (m.user_id = me or not is_blocked_between(me, m.user_id))
    ), '[]'::jsonb)
  )
  from events e, lateral (select e.creator_id = me or is_event_member(e.id, me) as inside) x
  where e.id = target;
$$;

drop function if exists create_event(text, text, text, date, time, text, uuid[], boolean);

-- group_id: an event of a group, for its members (never public).
create or replace function create_event(
  title text, description text, image_path text, event_date date, event_time time, location text,
  invitees uuid[] default '{}', is_public boolean default false, group_id uuid default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  new_id uuid;
begin
  perform yg_check_event(title, description, location);
  perform yg_check_own_path(me, image_path);
  if create_event.group_id is not null then perform yg_require_group_member(me, create_event.group_id); end if;
  insert into events (creator_id, title, description, image_path, date, time, location, is_public, group_id)
  values (me, trim(title), trim(coalesce(description, '')), image_path, event_date, event_time, trim(location),
          coalesce(create_event.is_public, false) and create_event.group_id is null, create_event.group_id)
  returning id into new_id;
  insert into event_members (event_id, user_id, status, invited_by, responded_at) values (new_id, me, 'going', me, now());
  perform yg_invite_to_event(me, new_id, invitees);
  return event_json(me, new_id);
end;
$$;

-- Returns { event, removed_path }: the previous image when it was replaced or removed.
create or replace function update_event(
  target uuid, title text, description text, image_path text, event_date date, event_time time, location text,
  is_public boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  ev events;
begin
  select * into ev from events where id = target;
  if ev.id is null then raise exception 'yg:not_found:Este evento ya no existe.'; end if;
  if ev.creator_id <> me then raise exception 'yg:forbidden:Solo quien crea el evento puede editarlo.'; end if;
  perform yg_check_event(title, description, location);
  if image_path is distinct from ev.image_path then perform yg_check_own_path(me, image_path); end if;
  update events set
    title = trim(update_event.title),
    description = trim(coalesce(update_event.description, '')),
    image_path = update_event.image_path,
    date = event_date,
    time = event_time,
    location = trim(update_event.location),
    -- A group's event stays the group's.
    is_public = coalesce(update_event.is_public, false) and ev.group_id is null,
    updated_at = now()
  where id = target;
  return jsonb_build_object(
    'event', event_json(me, target),
    'removed_path', case when ev.image_path is distinct from image_path then ev.image_path end
  );
end;
$$;

-- Invited people answer; in a public or group event anyone who can see it joins by answering.
create or replace function respond_event(target uuid, answer rsvp_status) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  ev events;
begin
  if answer = 'pending' then raise exception 'yg:validation:Respuesta no válida.'; end if;
  select * into ev from events where id = target;
  if ev.id is null then raise exception 'yg:not_found:Este evento ya no existe.'; end if;
  update event_members set status = answer, responded_at = now() where event_id = target and user_id = me;
  if not found then
    if not ((ev.is_public or ev.group_id is not null) and can_see_event(me, target)) then
      raise exception 'yg:forbidden:No estás invitado a este evento.';
    end if;
    insert into event_members (event_id, user_id, status, invited_by, responded_at) values (target, me, answer, me, now());
  end if;
  return event_json(me, target);
end;
$$;

-- A group's events, for its members.
create or replace function list_group_events(target uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := yg_me();
begin
  perform yg_require_group_member(me, target);
  return coalesce((
    select jsonb_agg(event_json(me, e.id) order by e.date, e.time)
    from events e where e.group_id = target and can_see_event(me, e.id)
  ), '[]'::jsonb);
end;
$$;

-- ---- Counters in Inicio -----------------------------------------------------------------------

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
    -- Requests to join the groups you administer, by group.
    'group_request_ids', coalesce((
      select jsonb_agg(r.group_id) from group_join_requests r
      where yg_is_group_admin(r.group_id, me.id) and not is_blocked_between(me.id, r.user_id)
    ), '[]'::jsonb),
    'group_notice_count', (select count(*) from group_notices n where n.user_id = me.id),
    'unread', coalesce((
      select jsonb_agg(jsonb_build_object('type', n.type, 'target_id', n.target_id) order by n.created_at desc)
      from notifications n where n.user_id = me.id and n.read_at is null
    ), '[]'::jsonb)
  )
  from me;
$$;

-- ---- Reports and moderation -------------------------------------------------------------------

alter table reports drop constraint if exists reports_target_type_check;
alter table reports add constraint reports_target_type_check
  check (target_type in ('status', 'photo', 'comment', 'wall_message', 'profile', 'message', 'group_post', 'group_reply'));
alter table moderation_removals drop constraint if exists moderation_removals_content_kind_check;
alter table moderation_removals add constraint moderation_removals_content_kind_check
  check (content_kind in ('status', 'photo', 'comment', 'wall_message', 'message', 'group_post', 'group_reply'));

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
  elsif kind = 'group_post' then
    -- Members of the group only.
    select p.author_id, jsonb_build_object('text', p.text, 'storage_path', p.photo_path, 'group', g.name) into owner, copy
    from group_posts p join groups g on g.id = p.group_id
    where p.id = target and yg_is_group_member(p.group_id, me);
  elsif kind = 'group_reply' then
    select r.author_id, jsonb_build_object('text', r.text, 'group', g.name) into owner, copy
    from group_replies r join group_posts p on p.id = r.post_id join groups g on g.id = p.group_id
    where r.id = target and yg_is_group_member(p.group_id, me);
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

-- In the Gallinero: 30% of the group's members, at least 3 and at most 10.
create or replace function yg_report_threshold(kind text, target uuid) returns int
language sql stable security definer set search_path = public as $$
  select case
    when kind = 'message' then case when (
      select count(*) from conversation_members cm
      where cm.conversation_id = (select conversation_id from messages where id = target)
    ) > 5 then 2 else 1 end
    when kind in ('group_post', 'group_reply') then greatest(3, least(10, ceil(0.3 * yg_group_member_count(
      case when kind = 'group_post' then (select group_id from group_posts where id = target)
      else (select p.group_id from group_replies r join group_posts p on p.id = r.post_id where r.id = target) end
    ))::int))
    else coalesce((select value::int from app_settings where key = 'report_threshold'), 10)
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
    when 'group_post' then exists (select 1 from group_posts where id = r.target_id)
    when 'group_reply' then exists (select 1 from group_replies where id = r.target_id)
  end;
$$;

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
    when 'group_post' then jsonb_build_object(
      'group_post', (select to_jsonb(p) from group_posts p where p.id = target),
      'replies', coalesce((select jsonb_agg(to_jsonb(r)) from group_replies r where r.post_id = target), '[]'::jsonb),
      'grrs', coalesce((select jsonb_agg(to_jsonb(g)) from group_post_grrs g where g.post_id = target), '[]'::jsonb))
    when 'group_reply' then jsonb_build_object('group_reply', (select to_jsonb(r) from group_replies r where r.id = target))
  end;
$$;

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
    elsif r.content_kind = 'group_post' then
      -- Its group (or its author's place in it) must still exist.
      insert into group_posts select * from jsonb_populate_record(null::group_posts, d -> 'group_post');
      insert into group_replies select * from jsonb_populate_recordset(null::group_replies, d -> 'replies') on conflict do nothing;
      insert into group_post_grrs select * from jsonb_populate_recordset(null::group_post_grrs, d -> 'grrs') on conflict do nothing;
    elsif r.content_kind = 'group_reply' then
      insert into group_replies select * from jsonb_populate_record(null::group_replies, d -> 'group_reply');
    end if;
  exception when others then
    perform set_config('yg.restoring', 'off', true);
    return false;
  end;
  perform set_config('yg.restoring', 'off', true);
  return true;
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
    -- A copy is kept apart for the appeal, and its owner gets a notice (once).
    if r.target_owner_id is not null and not r.content_removed and r.target_type <> 'profile' then
      insert into moderation_removals (report_id, owner_id, content_kind, content_id, reason, data, storage_path)
      values (r.id, r.target_owner_id, r.target_type, r.target_id, r.reason, yg_removal_snapshot(r.target_type, r.target_id),
              case r.target_type
                when 'photo' then (select storage_path from photos where id = r.target_id)
                when 'group_post' then (select photo_path from group_posts where id = r.target_id)
              end);
    end if;
    if r.target_type = 'status' then delete from posts where id = r.target_id;
    elsif r.target_type = 'photo' then delete from photos where id = r.target_id;
    elsif r.target_type = 'comment' then delete from comments where id = r.target_id;
    elsif r.target_type = 'wall_message' then delete from wall_messages where id = r.target_id;
    elsif r.target_type = 'message' then update messages set text = '', deleted_at = now() where id = r.target_id and deleted_at is null;
    elsif r.target_type = 'group_post' then delete from group_posts where id = r.target_id;
    elsif r.target_type = 'group_reply' then delete from group_replies where id = r.target_id;
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
          r.data #>> '{wall_message,text}', r.data #>> '{group_post,text}', r.data #>> '{group_reply,text}', r.data ->> 'text'),
        'storage_path', r.storage_path
      ) order by r.appealed_at)
    from moderation_removals r where r.appealed_at is not null and r.decision is null
  ), '[]'::jsonb);
end;
$$;

create or replace function yg_can_delete_removed_photo(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select is_moderator()
    and exists (select 1 from reports r where r.snapshot ->> 'storage_path' = path and r.content_removed)
    and not exists (select 1 from photos ph where ph.storage_path = path)
    and not exists (select 1 from group_posts p where p.photo_path = path)
    and not exists (select 1 from moderation_removals m where m.storage_path = path and not yg_removal_final(m));
$$;

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
        or exists (select 1 from group_posts p where p.photo_path = o.name)
        or exists (select 1 from reports r where r.snapshot ->> 'storage_path' = o.name and r.status = 'pending')
        -- Removed photos that can still be appealed.
        or exists (select 1 from moderation_removals m where m.storage_path = o.name and not yg_removal_final(m))))
      or (o.bucket_id = 'avatars' and exists (select 1 from profiles p where p.avatar_url like '%/avatars/' || o.name))
      or (o.bucket_id = 'covers' and exists (select 1 from profiles p where p.cover_path = o.name))
    )
  order by o.created_at;
$$;
revoke execute on function admin_storage_orphans() from public, anon, authenticated;

-- ---- Groups nobody joined -----------------------------------------------------------------

-- Every night: user groups nobody joined in 7 days go, and their creator gets a
-- notice; notices older than 30 days go too.
create or replace function yg_cleanup_groups() returns int
language plpgsql volatile security definer set search_path = public as $$
declare
  n int;
begin
  insert into group_notices (user_id, group_name)
  select g.created_by, g.name from groups g
  where g.kind = 'user' and g.first_joined_at is null and g.created_at < now() - interval '7 days' and g.created_by is not null;
  delete from groups g where g.kind = 'user' and g.first_joined_at is null and g.created_at < now() - interval '7 days';
  get diagnostics n = row_count;
  delete from group_notices where created_at < now() - interval '30 days';
  return n;
end;
$$;
revoke execute on function yg_cleanup_groups() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('youngrr-groups', '50 3 * * *', 'select public.yg_cleanup_groups()');
  end if;
exception when others then
  raise notice 'pg_cron no disponible: programa yg_cleanup_groups() a mano (%).', sqlerrm;
end;
$$;

-- ---- Deleting an account: groups go on without the person ----------------------------------

create or replace function delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me_setup();
  remaining int;
  conv uuid;
  g uuid;
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
  -- Groups too: the owner's role passes on (their posts go with the account).
  for g in select group_id from group_members where user_id = me loop
    perform yg_leave_group(me, g);
  end loop;
  -- Invitations that brought this person in hold their email.
  delete from invitations where used_by = me;
  delete from notifications where actor_id = me or user_id = me;

  delete from auth.users where id = me;
end;
$$;

-- ---- API ----------------------------------------------------------------------------------------

grant execute on function list_my_groups() to authenticated;
grant execute on function group_invitations() to authenticated;
grant execute on function search_groups(text) to authenticated;
grant execute on function get_group(uuid) to authenticated;
grant execute on function create_group(text, text, boolean) to authenticated;
grant execute on function update_group(uuid, text, text, boolean) to authenticated;
grant execute on function delete_group(uuid) to authenticated;
grant execute on function invite_to_group(uuid, uuid[]) to authenticated;
grant execute on function answer_group_invite(uuid, boolean) to authenticated;
grant execute on function request_to_join_group(uuid) to authenticated;
grant execute on function cancel_group_request(uuid) to authenticated;
grant execute on function answer_group_request(uuid, uuid, boolean) to authenticated;
grant execute on function leave_group(uuid) to authenticated;
grant execute on function remove_group_member(uuid, uuid) to authenticated;
grant execute on function set_group_role(uuid, uuid, text) to authenticated;
grant execute on function mark_group_seen(uuid) to authenticated;
grant execute on function my_group_notices() to authenticated;
grant execute on function dismiss_group_notice(uuid) to authenticated;
grant execute on function list_group_posts(uuid, timestamptz, int) to authenticated;
grant execute on function create_group_post(uuid, text, text, int, int) to authenticated;
grant execute on function delete_group_post(uuid) to authenticated;
grant execute on function add_group_reply(uuid, text) to authenticated;
grant execute on function delete_group_reply(uuid) to authenticated;
grant execute on function set_group_grr(uuid, boolean) to authenticated;
grant execute on function list_group_events(uuid) to authenticated;
grant execute on function create_event(text, text, text, date, time, text, uuid[], boolean, uuid) to authenticated;

-- ---- Data export: groups ------------------------------------------------------------------------

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
    'groups', coalesce((select jsonb_agg(jsonb_build_object('name', g.name, 'privacy', g.privacy, 'role', gm.role, 'joined_at', gm.joined_at) order by gm.joined_at)
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

-- The terms and privacy policy now explain groups: everyone accepts them
-- again. Must match LEGAL.version in src/config/app.js.
create or replace function yg_terms_version() returns text
language sql immutable as $$ select '2026-09-30.4'::text $$;
