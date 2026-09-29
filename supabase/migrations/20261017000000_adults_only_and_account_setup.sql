-- YOUNGrr is only for people aged 18 or over; the town is optional; accounts
-- created by an administrator must set their own password; invitations no
-- longer reveal whether an email is registered (audit R09, R10, P2).

alter table profiles add column adult_confirmed_at timestamptz;
alter table profiles add column must_change_password boolean not null default false;

-- Accounts already created by hand (see needs_setup) got a temporary password.
update profiles set must_change_password = true where needs_setup;

-- ---- Age check at sign up ------------------------------------------------------------
-- The birth date is only used to check the age: it is removed from the sign-up
-- metadata before it is stored, and only the confirmation is kept.

create or replace function yg_is_adult(birth date) returns boolean
language sql immutable as $$
  select birth is not null and birth <= (current_date - interval '18 years')::date and birth >= date '1900-01-01';
$$;

create or replace function on_auth_user_age_check() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  birth date;
begin
  -- Accounts created by an administrator confirm their age when they first sign in.
  if new.invited_at is not null then return new; end if;
  begin
    birth := (new.raw_user_meta_data ->> 'birth_date')::date;
  exception when others then
    birth := null;
  end;
  if not yg_is_adult(birth) then
    raise exception 'YOUNGrr es solo para mayores de 18 años.';
  end if;
  new.raw_user_meta_data := (new.raw_user_meta_data - 'birth_date') || jsonb_build_object('adult_confirmed', true);
  return new;
end;
$$;
create trigger auth_user_age_check before insert on auth.users for each row execute function on_auth_user_age_check();

-- Profile at sign up: the town is optional; the age confirmation is kept.
create or replace function on_auth_user_created() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, first_name, last_name, city, city_lat, city_lng, adult_confirmed_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce(new.raw_user_meta_data ->> 'city', ''),
    nullif(new.raw_user_meta_data ->> 'city_lat', '')::double precision,
    nullif(new.raw_user_meta_data ->> 'city_lng', '')::double precision,
    case when (new.raw_user_meta_data ->> 'adult_confirmed') = 'true' then now() end
  );
  insert into user_settings (user_id) values (new.id);
  insert into albums (owner_id, kind, title, description) values (new.id, 'wall', 'Fotos del muro', 'Fotografías publicadas en el muro.');
  return new;
end;
$$;

-- For accounts that did not confirm it at sign up (older or created by hand).
create or replace function confirm_adult(birth_date date) returns profiles
language plpgsql security definer set search_path = public as $$
declare
  result profiles;
begin
  if not yg_is_adult(birth_date) then
    raise exception 'yg:forbidden:YOUNGrr es solo para mayores de 18 años.';
  end if;
  update profiles set adult_confirmed_at = coalesce(adult_confirmed_at, now()) where id = yg_me() returning * into result;
  return result;
end;
$$;

-- ---- Temporary passwords -------------------------------------------------------------
-- The flag goes away only when the password really changes in Supabase Auth.

create or replace function on_auth_user_password_changed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.encrypted_password is distinct from old.encrypted_password then
    update profiles set must_change_password = false where id = new.id and must_change_password;
  end if;
  return new;
end;
$$;
create trigger auth_user_password_changed after update of encrypted_password on auth.users
  for each row execute function on_auth_user_password_changed();

-- Name and town (optional) for accounts created by hand.
create or replace function complete_profile_setup(first_name text, last_name text, city text, city_lat double precision, city_lng double precision)
returns profiles
language plpgsql security definer set search_path = public as $$
declare
  me uuid := yg_me();
  result profiles;
begin
  first_name := trim(coalesce(first_name, ''));
  last_name := trim(coalesce(last_name, ''));
  city := trim(coalesce(city, ''));
  if char_length(first_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu nombre (máximo 40 caracteres).'; end if;
  if char_length(last_name) not between 1 and 40 then raise exception 'yg:validation:Escribe tu apellido (máximo 40 caracteres).'; end if;
  if city <> '' and (char_length(city) > 60 or city_lat is null or city_lng is null) then
    raise exception 'yg:validation:Elige tu ciudad o pueblo de la lista.';
  end if;
  update profiles p set
    first_name = complete_profile_setup.first_name,
    last_name = complete_profile_setup.last_name,
    city = complete_profile_setup.city,
    city_lat = case when complete_profile_setup.city = '' then null else complete_profile_setup.city_lat end,
    city_lng = case when complete_profile_setup.city = '' then null else complete_profile_setup.city_lng end,
    needs_setup = false
  where p.id = me
  returning * into result;
  return result;
end;
$$;

-- Creates an account by hand with a random temporary password, returned once.
-- Only for the SQL editor (not granted to the API). The person must change it
-- at first sign in; unused temporary passwords expire (see run_retention).
create or replace function admin_create_account(account_email text, account_first_name text)
returns table (email text, temporary_password text)
language plpgsql security definer set search_path = public, extensions as $$
declare
  address text := lower(trim(account_email));
  secret text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 20);
  new_id uuid := gen_random_uuid();
begin
  if address !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Correo no válido.'; end if;
  if exists (select 1 from auth.users u where u.email = address) then raise exception 'Ya existe una cuenta con ese correo.'; end if;
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', new_id, 'authenticated', 'authenticated', address,
    extensions.crypt(secret, extensions.gen_salt('bf')), now(), now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object('first_name', trim(account_first_name), 'last_name', '-'),
    now(), now(), '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), new_id, new_id::text,
    jsonb_build_object('sub', new_id::text, 'email', address, 'email_verified', true), 'email', now(), now(), now());
  update profiles set needs_setup = true, must_change_password = true where id = new_id;
  return query select address, secret;
end;
$$;
revoke execute on function admin_create_account(text, text) from public, anon, authenticated;

grant execute on function confirm_adult(date) to authenticated;

-- ---- Invitations do not reveal whether an email is registered ------------------------
-- Inviting a registered email works like any other; that person simply cannot
-- create a second account with it.

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
  if yg_invites_used(me) >= 5 then raise exception 'yg:forbidden:No te quedan invitaciones disponibles.'; end if;
  insert into invitations (inviter_id, email) values (me, address) returning * into inv;
  return invitation_json(inv);
end;
$$;
