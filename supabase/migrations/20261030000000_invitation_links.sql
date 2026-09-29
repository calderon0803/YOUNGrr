-- Invitations become single-use links: the inviter just creates a link and
-- sends it; whoever opens it signs up with their own email. Invitations no
-- longer hold anybody's email (old ones keep theirs until they are cleaned up).
-- Each link works once: a second sign up with the same link is rejected, even
-- if both arrive at the same time.

alter table invitations alter column email drop not null;

-- The link no longer depends on an email.
drop function if exists create_invitation(text);

create or replace function create_invitation() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  inv invitations;
begin
  if yg_invites_used(me) >= yg_invites_earned(me) then
    raise exception 'yg:forbidden:No te quedan invitaciones disponibles.';
  end if;
  insert into invitations (inviter_id) values (me) returning * into inv;
  return invitation_json(inv);
end;
$$;

grant execute on function create_invitation() to authenticated;

-- For the sign up page, before having an account: who invites.
create or replace function check_invitation(invite_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'inviter', jsonb_build_object('first_name', p.first_name, 'last_name', p.last_name, 'avatar_url', p.avatar_url)
  )
  from invitations i join profiles p on p.id = i.inviter_id
  where i.token = invite_token and i.used_by is null and i.expires_at > now();
$$;

-- ---- Sign up: a valid link, whatever the email ---------------------------------------------
-- Old invitations made for an email still only work with that email.

create or replace function on_auth_user_invite_check() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.invited_at is not null then return new; end if;
  if not exists (
    select 1 from invitations
    where token = new.raw_user_meta_data ->> 'invite_token'
      and (email is null or email = lower(new.email)) and used_by is null and expires_at > now()
  ) then
    raise exception 'YOUNGrr es solo por invitación.';
  end if;
  return new;
end;
$$;

create or replace function on_auth_user_invited() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  inv invitations;
begin
  if new.invited_at is not null then return new; end if;
  update invitations set used_by = new.id, used_at = now()
  where token = new.raw_user_meta_data ->> 'invite_token'
    and (email is null or email = lower(new.email)) and used_by is null and expires_at > now()
  returning * into inv;
  -- Somebody else used the link a moment before: this sign up is cancelled.
  if inv.id is null then
    raise exception 'YOUNGrr es solo por invitación.';
  end if;
  insert into friendships (user_a, user_b) values (least(inv.inviter_id, new.id), greatest(inv.inviter_id, new.id)) on conflict do nothing;
  perform push_notification(inv.inviter_id, new.id, 'friend_accepted', new.id);
  return new;
end;
$$;

update retention_settings
set note = 'Invitaciones caducadas sin usar: se borran al caducar.'
where key = 'invitations_expired';
