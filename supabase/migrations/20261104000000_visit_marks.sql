-- Profile visits: the same person counts at most once per profile every 6
-- hours, from any device.
--
-- To know that without keeping who visited whom, each visit leaves only a
-- mark: a SHA-256 of a secret salt, the visitor and the profile. It holds no
-- readable id, nobody can read it (no API access) and it is deleted after 6
-- hours. The profile keeps only its total.

-- Secret salt for the marks, readable only by the database's own functions.
create table app_secrets (
  key   text primary key,
  value text not null
);
alter table app_secrets enable row level security;
revoke all on table app_secrets from authenticated, anon;
insert into app_secrets (key, value)
values ('visit_salt', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
on conflict (key) do nothing;

create table visit_marks (
  mark       text primary key,
  expires_at timestamptz not null
);
alter table visit_marks enable row level security;
revoke all on table visit_marks from authenticated, anon;

create or replace function register_visit(profile uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  m text;
  fresh int;
begin
  if me is null or profile = me or not can_view_profile(me, profile) then
    return;
  end if;
  m := encode(sha256(convert_to((select value from app_secrets where key = 'visit_salt') || ':' || me || ':' || profile, 'UTF8')), 'hex');
  -- A mark older than 6 hours no longer counts; clean up the old ones now and then.
  delete from visit_marks where mark = m and expires_at <= now();
  if random() < 0.05 then delete from visit_marks where expires_at <= now(); end if;
  insert into visit_marks (mark, expires_at) values (m, now() + interval '6 hours') on conflict do nothing;
  get diagnostics fresh = row_count;
  if fresh = 0 then return; end if;
  update profiles set visit_count = visit_count + 1 where id = profile;
end;
$$;
