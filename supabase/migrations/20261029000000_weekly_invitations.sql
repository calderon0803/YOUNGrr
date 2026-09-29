-- Invitations are earned over time: 1 at sign up and 1 more each full week
-- since then, up to 5 in total. As before, an invitation counts while it is
-- pending or once it has been used; cancelled or expired ones are given back.

create or replace function yg_invites_earned(person uuid) returns int
language sql stable security definer set search_path = public as $$
  select least(5, 1 + floor(extract(epoch from now() - p.created_at) / 604800)::int)
  from profiles p where p.id = person;
$$;

-- When the next one arrives (null once all 5 have been earned).
create or replace function yg_invites_next_at(person uuid) returns timestamptz
language sql stable security definer set search_path = public as $$
  select case when yg_invites_earned(person) < 5 then p.created_at + yg_invites_earned(person) * interval '7 days' end
  from profiles p where p.id = person;
$$;

create or replace function list_invitations() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'available', greatest(0, yg_invites_earned(yg_me()) - yg_invites_used(yg_me())),
    'next_at', yg_invites_next_at(yg_me()),
    'invitations', coalesce((
      select jsonb_agg(invitation_json(i) order by i.created_at desc)
      from invitations i where i.inviter_id = yg_me()
    ), '[]'::jsonb)
  );
$$;

create or replace function create_invitation(invitee_email text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  address text := lower(trim(coalesce(invitee_email, '')));
  inv invitations;
begin
  if address !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'yg:validation:Escribe un correo válido.'; end if;
  select * into inv from invitations
  where inviter_id = me and email = address and used_by is null and expires_at > now();
  if inv.id is not null then return invitation_json(inv); end if;
  if yg_invites_used(me) >= yg_invites_earned(me) then
    raise exception 'yg:forbidden:No te quedan invitaciones disponibles.';
  end if;
  insert into invitations (inviter_id, email) values (me, address) returning * into inv;
  return invitation_json(inv);
end;
$$;
