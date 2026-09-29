-- Data that no longer has a purpose is deleted (audit §13).
--
-- The periods are TECHNICAL PLACEHOLDERS, not legal decisions: they live in
-- `retention_settings` so they can be changed once validated, e.g.
--   update retention_settings set days = 60 where key = 'notifications_read';

create table retention_settings (
  key  text primary key,
  days int not null check (days >= 0),
  note text not null default ''
);
alter table retention_settings enable row level security;
revoke all on table retention_settings from authenticated, anon;

insert into retention_settings (key, days, note) values
  ('invitations_expired', 0, 'Invitaciones caducadas o sin usar: se borran al caducar (guardan el email de un tercero). Pendiente de validación jurídica.'),
  ('notifications_read', 90, 'Avisos ya vistos. Plazo técnico provisional.'),
  ('notifications_unread', 365, 'Avisos nunca vistos. Plazo técnico provisional.'),
  ('friend_requests_closed', 30, 'Solicitudes rechazadas o canceladas. Plazo técnico provisional.'),
  ('photo_owner_invites_closed', 30, 'Invitaciones para compartir fotos rechazadas. Plazo técnico provisional.'),
  ('temporary_password_days', 7, 'Cuentas creadas a mano que no han cambiado la contraseña provisional: se bloquean. Plazo técnico provisional.'),
  ('reports_closed', 365, 'Reportes resueltos o descartados. Pendiente de validación jurídica (posibles obligaciones de conservación).')
on conflict (key) do nothing;

create or replace function yg_retention_days(setting text) returns int
language sql stable security definer set search_path = public as $$
  select days from retention_settings where key = setting;
$$;

-- Runs the clean-up and returns how many rows each step removed.
create or replace function run_retention() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  result jsonb := '{}'::jsonb;
  n int;
begin
  delete from invitations
  where used_by is null and expires_at < now() - make_interval(days => yg_retention_days('invitations_expired'));
  get diagnostics n = row_count; result := result || jsonb_build_object('invitations', n);

  delete from notifications
  where (read_at is not null and read_at < now() - make_interval(days => yg_retention_days('notifications_read')))
     or (read_at is null and created_at < now() - make_interval(days => yg_retention_days('notifications_unread')));
  get diagnostics n = row_count; result := result || jsonb_build_object('notifications', n);

  delete from friend_requests
  where status in ('rejected', 'cancelled')
    and coalesce(responded_at, created_at) < now() - make_interval(days => yg_retention_days('friend_requests_closed'));
  get diagnostics n = row_count; result := result || jsonb_build_object('friend_requests', n);

  delete from photo_owners
  where status = 'rejected' and created_at < now() - make_interval(days => yg_retention_days('photo_owner_invites_closed'));
  get diagnostics n = row_count; result := result || jsonb_build_object('photo_owner_invites', n);

  delete from reports
  where status <> 'pending' and resolved_at < now() - make_interval(days => yg_retention_days('reports_closed'));
  get diagnostics n = row_count; result := result || jsonb_build_object('reports', n);

  -- Temporary passwords do not stay usable forever: the account is blocked
  -- until an administrator creates a new temporary password.
  update auth.users u set banned_until = 'infinity'
  from profiles p
  where p.id = u.id and p.must_change_password
    and u.created_at < now() - make_interval(days => yg_retention_days('temporary_password_days'))
    and (u.banned_until is null or u.banned_until < now());
  get diagnostics n = row_count; result := result || jsonb_build_object('temporary_accounts_blocked', n);

  return result;
end;
$$;

-- Files in Storage that no row points to (older than a day, so uploads in
-- progress are not listed). Delete them from the Storage panel or API.
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
        or exists (select 1 from reports r where r.snapshot ->> 'storage_path' = o.name and r.status = 'pending')))
      or (o.bucket_id = 'avatars' and exists (select 1 from profiles p where p.avatar_url like '%/avatars/' || o.name))
      or (o.bucket_id = 'covers' and exists (select 1 from profiles p where p.cover_path = o.name))
    )
  order by o.created_at;
$$;

revoke execute on function run_retention() from public, anon, authenticated;
revoke execute on function admin_storage_orphans() from public, anon, authenticated;

-- Daily run with pg_cron when the extension is available. If it is not, enable
-- it in Supabase (Database > Extensions > pg_cron) and run:
--   select cron.schedule('youngrr-retention', '15 3 * * *', 'select public.run_retention()');
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('youngrr-retention', '15 3 * * *', 'select public.run_retention()');
  end if;
exception when others then
  raise notice 'pg_cron no disponible: programa run_retention() a mano (%).', sqlerrm;
end;
$$;
