-- Invitation-only sign up, as Tuenti was: a registered user invites a friend by
-- email and gets a personal link to send them. The account can only be created
-- with that email and a valid invitation; inviter and invitee become friends.

create table invitations (
  id          uuid primary key default gen_random_uuid(),
  token       text not null unique default replace(gen_random_uuid()::text, '-', ''),
  inviter_id  uuid not null references profiles (id) on delete cascade,
  email       text not null check (email = lower(trim(email)) and email like '%_@_%._%'),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '30 days',
  used_by     uuid references profiles (id) on delete set null,
  used_at     timestamptz
);
create index invitations_inviter on invitations (inviter_id, created_at desc);

alter table invitations enable row level security;
create policy "own invitations" on invitations for select to authenticated using (inviter_id = auth.uid());

-- Invitations each person can have in use (accepted or still pending).
create or replace function yg_invites_used(person uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from invitations
  where inviter_id = person and (used_by is not null or expires_at > now());
$$;

create or replace function invitation_json(i invitations) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', i.id,
    'email', i.email,
    'created_at', i.created_at,
    'expires_at', i.expires_at,
    'used_at', i.used_at,
    -- The link only makes sense while the invitation is pending.
    'token', case when i.used_by is null and i.expires_at > now() then i.token end,
    'used_by', case when i.used_by is null then null else person_summary(i.used_by) end
  );
$$;

create or replace function list_invitations() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'available', greatest(0, 10 - yg_invites_used(yg_me())),
    'invitations', coalesce((
      select jsonb_agg(invitation_json(i) order by i.created_at desc)
      from invitations i where i.inviter_id = yg_me()
    ), '[]'::jsonb)
  );
$$;

-- Returns the pending invitation for that email if there is one already.
create or replace function create_invitation(invitee_email text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  address text := lower(trim(coalesce(invitee_email, '')));
  inv invitations;
begin
  if address !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'yg:validation:Escribe un correo válido.'; end if;
  if exists (select 1 from auth.users where lower(email) = address) then
    raise exception 'yg:conflict:Esa persona ya tiene cuenta en YOUNGrr. Búscala y envíale una solicitud de amistad.';
  end if;
  select * into inv from invitations
  where inviter_id = me and email = address and used_by is null and expires_at > now();
  if inv.id is not null then return invitation_json(inv); end if;
  if yg_invites_used(me) >= 10 then raise exception 'yg:forbidden:No te quedan invitaciones disponibles.'; end if;
  insert into invitations (inviter_id, email) values (me, address) returning * into inv;
  return invitation_json(inv);
end;
$$;

-- A pending invitation can be withdrawn; it is given back.
create or replace function cancel_invitation(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from invitations where id = target and inviter_id = yg_me() and used_by is null;
  if not found then raise exception 'yg:not_found:Esta invitación ya no se puede cancelar.'; end if;
end;
$$;

-- For the sign up page, before having an account: who invites and to which email.
create or replace function check_invitation(invite_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'email', i.email,
    'inviter', jsonb_build_object('first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url)
  )
  from invitations i join profiles p on p.id = i.inviter_id
  where i.token = invite_token and i.used_by is null and i.expires_at > now();
$$;

-- ---- Sign up only with an invitation -------------------------------------------------
-- Users invited from the Supabase dashboard (invited_at set) are let through.

create or replace function on_auth_user_invite_check() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.invited_at is not null then return new; end if;
  if not exists (
    select 1 from invitations
    where token = new.raw_user_meta_data ->> 'invite_token'
      and email = lower(new.email) and used_by is null and expires_at > now()
  ) then
    raise exception 'YOUNGrr es solo por invitación.';
  end if;
  return new;
end;
$$;
create trigger auth_user_invite_check before insert on auth.users for each row execute function on_auth_user_invite_check();

-- Runs after auth_user_created (triggers fire in name order), once the profile exists.
create or replace function on_auth_user_invited() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  inv invitations;
begin
  update invitations set used_by = new.id, used_at = now()
  where token = new.raw_user_meta_data ->> 'invite_token' and email = lower(new.email) and used_by is null
  returning * into inv;
  if inv.id is not null then
    insert into friendships (user_a, user_b) values (least(inv.inviter_id, new.id), greatest(inv.inviter_id, new.id)) on conflict do nothing;
    perform push_notification(inv.inviter_id, new.id, 'friend_accepted', new.id);
  end if;
  return new;
end;
$$;
create trigger auth_user_invited after insert on auth.users for each row execute function on_auth_user_invited();

grant execute on function list_invitations() to authenticated;
grant execute on function create_invitation(text) to authenticated;
grant execute on function cancel_invitation(uuid) to authenticated;
grant execute on function check_invitation(text) to anon, authenticated;
