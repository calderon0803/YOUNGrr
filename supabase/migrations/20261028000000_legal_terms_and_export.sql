-- Legal: acceptance of the terms and privacy policy, final retention periods
-- and the scope of "Descargar mis datos".
--
-- - The current version of the legal texts lives in yg_terms_version(). It must
--   match LEGAL.version in src/config/app.js: when the texts change, bump both
--   and everyone accepts the new version on their next sign in.
-- - New sign ups must send the version they accepted; accounts that have not
--   accepted the current one cannot use the API until they do (setup page).
-- - Retention periods, decided by the owner on 2026-09-29.
-- - The export includes whole conversations (messages received too).

alter table profiles add column terms_version text;
alter table profiles add column terms_accepted_at timestamptz;

create or replace function yg_terms_version() returns text
language sql immutable as $$ select '2026-09-29'::text $$;

-- ---- Sign up: age and terms ------------------------------------------------------------

create or replace function on_auth_user_age_check() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  birth date;
begin
  -- Accounts created by an administrator confirm their age and accept the
  -- terms when they first sign in.
  if new.invited_at is not null then return new; end if;
  begin
    birth := (new.raw_user_meta_data ->> 'birth_date')::date;
  exception when others then
    birth := null;
  end;
  if not yg_is_adult(birth) then
    raise exception 'YOUNGrr es solo para mayores de 18 años.';
  end if;
  if (new.raw_user_meta_data ->> 'terms_version') is distinct from yg_terms_version() then
    raise exception 'Hay que aceptar las condiciones y la política de privacidad.';
  end if;
  new.raw_user_meta_data := (new.raw_user_meta_data - 'birth_date') || jsonb_build_object('adult_confirmed', true);
  return new;
end;
$$;

create or replace function on_auth_user_created() returns trigger language plpgsql security definer set search_path = public as $$
declare
  accepted boolean := (new.raw_user_meta_data ->> 'terms_version') is not distinct from yg_terms_version();
begin
  insert into profiles (id, first_name, last_name, city, city_lat, city_lng, adult_confirmed_at, terms_version, terms_accepted_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce(new.raw_user_meta_data ->> 'city', ''),
    nullif(new.raw_user_meta_data ->> 'city_lat', '')::double precision,
    nullif(new.raw_user_meta_data ->> 'city_lng', '')::double precision,
    case when (new.raw_user_meta_data ->> 'adult_confirmed') = 'true' then now() end,
    case when accepted then yg_terms_version() end,
    case when accepted then now() end
  );
  insert into user_settings (user_id) values (new.id);
  insert into albums (owner_id, kind, title, description) values (new.id, 'wall', 'Fotos del muro', 'Fotografías publicadas en el muro.');
  return new;
end;
$$;

-- ---- Accepting the current version -------------------------------------------------------

create or replace function accept_terms(version text) returns profiles
language plpgsql security definer set search_path = public as $$
declare
  result profiles;
begin
  if version is distinct from yg_terms_version() then
    raise exception 'yg:conflict:Las condiciones han cambiado. Recarga la página para ver las nuevas.';
  end if;
  update profiles set terms_version = yg_terms_version(), terms_accepted_at = now()
  where id = yg_me_setup() returning * into result;
  return result;
end;
$$;

grant execute on function accept_terms(text) to authenticated;

create or replace function yg_me() returns uuid
language plpgsql stable set search_path = public as $$
declare
  me uuid := yg_me_setup();
  pending boolean;
begin
  select p.must_change_password or p.needs_setup or p.adult_confirmed_at is null
         or p.terms_version is distinct from yg_terms_version()
  into pending
  from profiles p where p.id = me;
  if pending then
    raise exception 'yg:setup_required:Completa tu cuenta antes de seguir.';
  end if;
  return me;
end;
$$;

-- ---- Retention periods -------------------------------------------------------------------

update retention_settings set
  days = case key
    when 'invitations_expired' then 0
    when 'notifications_read' then 90
    when 'notifications_unread' then 365
    when 'friend_requests_closed' then 30
    when 'photo_owner_invites_closed' then 30
    when 'temporary_password_days' then 7
    when 'reports_closed' then 365
    else days end,
  note = case key
    when 'invitations_expired' then 'Invitaciones caducadas sin usar: se borran al caducar (guardan el email de otra persona).'
    when 'notifications_read' then 'Avisos ya vistos: 90 días.'
    when 'notifications_unread' then 'Avisos nunca vistos: 1 año.'
    when 'friend_requests_closed' then 'Solicitudes de amistad rechazadas o canceladas: 30 días.'
    when 'photo_owner_invites_closed' then 'Invitaciones para compartir fotos rechazadas: 30 días.'
    when 'temporary_password_days' then 'Cuentas creadas a mano sin cambiar la contraseña provisional: se bloquean a los 7 días.'
    when 'reports_closed' then 'Reportes resueltos o descartados, con la copia del contenido: 1 año desde la decisión.'
    else note end;

-- ---- Data export: whole conversations and the terms accepted -----------------------------

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
    'albums', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'description', a.description, 'kind', a.kind, 'created_at', a.created_at) order by a.created_at)
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
        'with', (select coalesce(jsonb_agg(p.first_name || ' ' || p.last_name), '[]'::jsonb) from conversation_members cm join profiles p on p.id = cm.user_id
                 where cm.conversation_id = c.conversation_id and cm.user_id <> c.user_id),
        'messages', coalesce((select jsonb_agg(jsonb_build_object(
            'from', case when m.sender_id = c.user_id then 'yo' else (select p.first_name || ' ' || p.last_name from profiles p where p.id = m.sender_id) end,
            'text', case when m.deleted_at is null then m.text end,
            'deleted', m.deleted_at is not null,
            'created_at', m.created_at) order by m.created_at)
          from messages m where m.conversation_id = c.conversation_id), '[]'::jsonb)))
      from conversation_members c, me where c.user_id = me.id), '[]'::jsonb),
    'invitations_sent', coalesce((select jsonb_agg(jsonb_build_object('email', i.email, 'created_at', i.created_at, 'expires_at', i.expires_at, 'used', i.used_by is not null))
      from invitations i, me where i.inviter_id = me.id), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('about', r.target_type, 'reason', r.reason, 'status', r.status, 'created_at', r.created_at))
      from reports r, me where r.reporter_id = me.id), '[]'::jsonb)
  );
$$;
