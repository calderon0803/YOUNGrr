-- =============================================================================
-- YOUNGrr · PostgreSQL schema for Supabase (Auth + Postgres + Storage + RLS)
-- Mirrors the local mock backend in src/services/local. Run in the SQL editor
-- or as a migration. Privacy is enforced here, never only in the frontend.
-- =============================================================================

create extension if not exists "pgcrypto";

-- ---- Enums -------------------------------------------------------------------

create type visibility as enum ('everyone', 'friends', 'only_me');
create type request_policy as enum ('everyone', 'friends_of_friends', 'nobody');
create type friend_request_status as enum ('pending', 'accepted', 'rejected', 'cancelled');
create type grr_target as enum ('post', 'photo');
create type rsvp_status as enum ('going', 'maybe', 'declined', 'pending');
create type album_kind as enum ('user', 'wall');
create type notification_type as enum (
  'grr_post', 'grr_photo', 'comment_post', 'comment_photo', 'friend_request',
  'friend_accepted', 'event_invite', 'message', 'photo_tag', 'photo_owner_invite', 'photo_owner_accepted'
);

-- ---- Users & profiles ----------------------------------------------------------
-- "users" is auth.users (managed by Supabase Auth). Public data lives in profiles.

create table profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  first_name  text not null check (char_length(first_name) between 1 and 40),
  last_name   text not null check (char_length(last_name) between 1 and 40),
  avatar_url  text,
  cover_url   text,
  city        text not null default '' check (char_length(city) <= 60),
  -- Town-level coordinates from the geocoder. Never granted to clients (see below).
  city_lat    double precision check (city_lat between -90 and 90),
  city_lng    double precision check (city_lng between -180 and 180),
  bio         text not null default '' check (char_length(bio) <= 300),
  birthday    date,
  studies     text not null default '' check (char_length(studies) <= 80),
  work        text not null default '' check (char_length(work) <= 80),
  -- Tuenti-style visit counter: visits by other people, once per visitor and day.
  visit_count int not null default 0,
  created_at  timestamptz not null default now()
);

create table profile_visits (
  profile_id uuid not null references profiles (id) on delete cascade,
  visitor_id uuid not null references profiles (id) on delete cascade,
  day        date not null default current_date,
  primary key (profile_id, visitor_id, day)
);

create table user_settings (
  user_id              uuid primary key references profiles (id) on delete cascade,
  -- Friends always see your profile: only 'everyone' or 'friends'.
  profile_visibility   visibility not null default 'everyone' check (profile_visibility in ('everyone', 'friends')),
  city_visibility      visibility not null default 'friends',
  distance_visibility  visibility not null default 'friends',
  nearby_radius_km     int not null default 25 check (nearby_radius_km in (10, 25, 50)),
  friend_requests      request_policy not null default 'everyone',
  notify_grr           boolean not null default true,
  notify_comments      boolean not null default true,
  notify_friend_requests boolean not null default true,
  notify_events        boolean not null default true,
  notify_messages      boolean not null default true,
  notify_tags          boolean not null default true,
  theme                text not null default 'system' check (theme in ('system', 'light', 'dark'))
);

-- ---- Friends -------------------------------------------------------------------

-- One row per pair, always stored with user_a < user_b.
create table friendships (
  user_a     uuid not null references profiles (id) on delete cascade,
  user_b     uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);

create table friend_requests (
  id           uuid primary key default gen_random_uuid(),
  from_id      uuid not null references profiles (id) on delete cascade,
  to_id        uuid not null references profiles (id) on delete cascade,
  status       friend_request_status not null default 'pending',
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  check (from_id <> to_id)
);
-- Only one pending request per direction.
create unique index friend_requests_one_pending on friend_requests (from_id, to_id) where status = 'pending';

-- ---- Posts, photos, albums -----------------------------------------------------

create table albums (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references profiles (id) on delete cascade,
  kind           album_kind not null default 'user',
  title          text not null check (char_length(title) between 1 and 60),
  description    text not null default '' check (char_length(description) <= 300),
  cover_photo_id uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index albums_one_wall on albums (owner_id) where kind = 'wall';

create table photos (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references profiles (id) on delete cascade,
  album_id   uuid not null references albums (id) on delete cascade,
  -- Path inside the "photos" Storage bucket: <owner_id>/<photo_id>.jpg
  storage_path text not null,
  width      int not null check (width > 0),
  height     int not null check (height > 0),
  caption    text not null default '' check (char_length(caption) <= 200),
  created_at timestamptz not null default now()
);

alter table albums
  add constraint albums_cover_fk foreign key (cover_photo_id) references photos (id) on delete set null;

-- Co-owners of a photo: same rights as the uploader once they accept.
create type photo_owner_status as enum ('pending', 'accepted', 'rejected');

create table photo_owners (
  photo_id     uuid not null references photos (id) on delete cascade,
  user_id      uuid not null references profiles (id) on delete cascade,
  status       photo_owner_status not null default 'pending',
  invited_by   uuid not null references profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  primary key (photo_id, user_id)
);

create table posts (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid not null references profiles (id) on delete cascade,
  text       text not null default '' check (char_length(text) <= 2000),
  photo_id   uuid references photos (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  check (char_length(text) > 0 or photo_id is not null)
);
create index posts_author_created on posts (author_id, created_at desc);

create table photo_tags (
  id         uuid primary key default gen_random_uuid(),
  photo_id   uuid not null references photos (id) on delete cascade,
  user_id    uuid not null references profiles (id) on delete cascade,
  tagged_by  uuid not null references profiles (id) on delete cascade,
  x          real not null check (x between 0 and 1),
  y          real not null check (y between 0 and 1),
  created_at timestamptz not null default now(),
  unique (photo_id, user_id)
);

-- ---- Grr & comments ------------------------------------------------------------
-- A Grr targets exactly one post or one photo. Partial unique indexes keep
-- "one Grr per user and content": (user_id, post_id) and (user_id, photo_id).

create table grrs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles (id) on delete cascade,
  post_id    uuid references posts (id) on delete cascade,
  photo_id   uuid references photos (id) on delete cascade,
  created_at timestamptz not null default now(),
  check (num_nonnulls(post_id, photo_id) = 1)
);
create unique index grrs_unique_post on grrs (user_id, post_id) where post_id is not null;
create unique index grrs_unique_photo on grrs (user_id, photo_id) where photo_id is not null;

create table comments (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid not null references profiles (id) on delete cascade,
  post_id    uuid references posts (id) on delete cascade,
  photo_id   uuid references photos (id) on delete cascade,
  text       text not null check (char_length(text) between 1 and 500),
  created_at timestamptz not null default now(),
  check (num_nonnulls(post_id, photo_id) = 1)
);

create table hidden_posts (
  user_id uuid not null references profiles (id) on delete cascade,
  post_id uuid not null references posts (id) on delete cascade,
  primary key (user_id, post_id)
);

create table reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles (id) on delete cascade,
  post_id     uuid not null references posts (id) on delete cascade,
  reason      text not null,
  created_at  timestamptz not null default now()
);

-- ---- Events --------------------------------------------------------------------

create table events (
  id          uuid primary key default gen_random_uuid(),
  creator_id  uuid not null references profiles (id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 80),
  description text not null default '' check (char_length(description) <= 1500),
  image_url   text,
  date        date not null,
  time        time not null,
  location    text not null check (char_length(location) between 1 and 120),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table event_members (
  event_id     uuid not null references events (id) on delete cascade,
  user_id      uuid not null references profiles (id) on delete cascade,
  status       rsvp_status not null default 'pending',
  invited_by   uuid not null references profiles (id) on delete cascade,
  responded_at timestamptz,
  primary key (event_id, user_id)
);

-- ---- Messages ------------------------------------------------------------------

create table conversations (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table conversation_members (
  conversation_id uuid not null references conversations (id) on delete cascade,
  user_id         uuid not null references profiles (id) on delete cascade,
  last_read_at    timestamptz,
  primary key (conversation_id, user_id)
);

create table messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations (id) on delete cascade,
  sender_id       uuid not null references profiles (id) on delete cascade,
  text            text not null check (char_length(text) between 1 and 2000),
  created_at      timestamptz not null default now()
);
create index messages_conversation_created on messages (conversation_id, created_at);

-- ---- Notifications -------------------------------------------------------------

create table notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles (id) on delete cascade,
  actor_id   uuid not null references profiles (id) on delete cascade,
  type       notification_type not null,
  target_id  uuid not null,
  created_at timestamptz not null default now(),
  read_at    timestamptz,
  -- Repeating an action refreshes the notification instead of duplicating it.
  unique (user_id, actor_id, type, target_id)
);

-- =============================================================================
-- Helper functions (security definer so policies can use them without recursion)
-- =============================================================================

create or replace function are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships
    where user_a = least(a, b) and user_b = greatest(a, b)
  );
$$;

create or replace function mutual_friends(a uuid, b uuid) returns int
language sql stable security definer set search_path = public as $$
  with fa as (
    select case when user_a = a then user_b else user_a end as id from friendships where a in (user_a, user_b)
  ), fb as (
    select case when user_a = b then user_b else user_a end as id from friendships where b in (user_a, user_b)
  )
  select count(*)::int from fa join fb using (id);
$$;

create or replace function allowed_by(viewer uuid, owner uuid, v visibility) returns boolean
language sql stable as $$
  select viewer = owner
      or v = 'everyone'
      or (v = 'friends' and are_friends(viewer, owner));
$$;

create or replace function can_view_profile(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select allowed_by(viewer, owner, (select profile_visibility from user_settings where user_id = owner));
$$;

-- Account and profile share one privacy setting: posts follow it.
create or replace function can_view_post(viewer uuid, post_author uuid) returns boolean
language sql stable as $
  select can_view_profile(viewer, post_author);
$;

create or replace function can_view_city(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = public as $
  select can_view_profile(viewer, owner)
     and allowed_by(viewer, owner, (select city_visibility from user_settings where user_id = owner));
$;

create or replace function can_view_distance(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = public as $
  select can_view_profile(viewer, owner)
     and allowed_by(viewer, owner, (select distance_visibility from user_settings where user_id = owner));
$;

create or replace function is_photo_owner(u uuid, photo uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from photos where id = photo and owner_id = u)
      or exists (select 1 from photo_owners where photo_id = photo and user_id = u and status = 'accepted');
$$;

-- Photos have no permissions of their own: they follow their owners' profile
-- privacy. A co-owned photo shows in every owner's profile, so whoever can see
-- any of those profiles sees it. Tagged people need no exception (only friends tag).
create or replace function can_view_photo(viewer uuid, photo uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from photos ph where ph.id = photo and (ph.owner_id = viewer or can_view_profile(viewer, ph.owner_id)))
      or exists (
        select 1 from photo_owners o
        where o.photo_id = photo and o.status = 'accepted' and (o.user_id = viewer or can_view_profile(viewer, o.user_id))
      );
$$;

create or replace function is_event_member(e uuid, u uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from event_members where event_id = e and user_id = u);
$$;

create or replace function is_conversation_member(c uuid, u uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from conversation_members where conversation_id = c and user_id = u);
$$;

-- =============================================================================
-- Row Level Security
-- =============================================================================

alter table profiles enable row level security;
alter table user_settings enable row level security;
alter table friendships enable row level security;
alter table friend_requests enable row level security;
alter table albums enable row level security;
alter table photos enable row level security;
alter table posts enable row level security;
alter table photo_tags enable row level security;
alter table grrs enable row level security;
alter table comments enable row level security;
alter table hidden_posts enable row level security;
alter table reports enable row level security;
alter table events enable row level security;
alter table event_members enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table notifications enable row level security;

-- Profiles: name and avatar are always findable (search, requests). The other
-- columns are not granted on the table; they are only exposed through the
-- `profile_details` view, which blanks them when privacy says so.
create policy "profiles readable by signed-in users" on profiles for select to authenticated using (true);
create policy "own profile insert" on profiles for insert to authenticated with check (id = auth.uid());
create policy "own profile update" on profiles for update to authenticated using (id = auth.uid());

revoke select on profiles from authenticated, anon;
grant select (id, first_name, last_name, avatar_url, visit_count, created_at) on profiles to authenticated;

-- Who visited is never exposed, only the counter.
alter table profile_visits enable row level security;

-- Runs with the owner's rights (not security_invoker) so it can read the hidden
-- columns; auth.uid() still resolves to the caller.
create view profile_details as
  select p.id, p.first_name, p.last_name, p.avatar_url,
         case when can_view_profile(auth.uid(), p.id) then p.cover_url end as cover_url,
         case when can_view_city(auth.uid(), p.id) then p.city end as city,
         case when can_view_profile(auth.uid(), p.id) then p.bio end as bio,
         case when can_view_profile(auth.uid(), p.id) then p.birthday end as birthday,
         case when can_view_profile(auth.uid(), p.id) then p.studies end as studies,
         case when can_view_profile(auth.uid(), p.id) then p.work end as work,
         p.created_at
  from profiles p;

revoke all on profile_details from anon;
grant select on profile_details to authenticated;

create policy "own settings" on user_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Friendships are created only by accept_friend_request(); users may end their own.
create policy "friendships visible when profile visible" on friendships for select to authenticated
  using (auth.uid() in (user_a, user_b) or can_view_profile(auth.uid(), user_a) or can_view_profile(auth.uid(), user_b));
create policy "remove own friendship" on friendships for delete to authenticated
  using (auth.uid() in (user_a, user_b));

create policy "requests of the participants" on friend_requests for select to authenticated
  using (auth.uid() in (from_id, to_id));
create policy "send request" on friend_requests for insert to authenticated
  with check (from_id = auth.uid() and status = 'pending' and can_send_request(auth.uid(), to_id));
create policy "sender cancels, recipient rejects" on friend_requests for update to authenticated
  using (auth.uid() in (from_id, to_id))
  with check (
    (from_id = auth.uid() and status = 'cancelled')
    or (to_id = auth.uid() and status in ('rejected', 'accepted'))
  );

-- Albums and photos have no permissions of their own: they follow profile privacy.
create policy "albums visible" on albums for select to authenticated using (can_view_profile(auth.uid(), owner_id));
create policy "albums owner writes" on albums for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "photos visible" on photos for select to authenticated using (can_view_photo(auth.uid(), id));
create policy "uploader inserts photos" on photos for insert to authenticated with check (owner_id = auth.uid());
-- Any owner edits (caption); leaving/deleting goes through leave_photo().
create policy "owners update photos" on photos for update to authenticated using (is_photo_owner(auth.uid(), id));

alter table photo_owners enable row level security;
create policy "owners and invitees see co-owners" on photo_owners for select to authenticated
  using (user_id = auth.uid() or is_photo_owner(auth.uid(), photo_id));
create policy "owners invite friends" on photo_owners for insert to authenticated
  with check (invited_by = auth.uid() and status = 'pending' and is_photo_owner(auth.uid(), photo_id) and are_friends(auth.uid(), user_id));
create policy "invitee answers" on photo_owners for update to authenticated
  using (user_id = auth.uid() and status = 'pending') with check (user_id = auth.uid() and status in ('accepted', 'rejected'));
create policy "co-owner leaves" on photo_owners for delete to authenticated using (user_id = auth.uid());

-- Posts are for friends: no public timeline, no strangers.
create policy "posts for friends" on posts for select to authenticated using (can_view_post(auth.uid(), author_id));
create policy "own posts insert" on posts for insert to authenticated with check (author_id = auth.uid());
create policy "own posts update" on posts for update to authenticated using (author_id = auth.uid());
create policy "own posts delete" on posts for delete to authenticated using (author_id = auth.uid());

create policy "tags visible with photo" on photo_tags for select to authenticated
  using (can_view_photo(auth.uid(), photo_id));
-- Only owners tag, each one themselves or their own friends.
create policy "uploader tags self or friends" on photo_tags for insert to authenticated
  with check (
    tagged_by = auth.uid()
    and is_photo_owner(auth.uid(), photo_id)
    and (user_id = auth.uid() or are_friends(auth.uid(), user_id))
  );
create policy "untag: tagged person or owner" on photo_tags for delete to authenticated
  using (auth.uid() = user_id or is_photo_owner(auth.uid(), photo_id));

-- Grr: visible and allowed only on content you can see; you manage only yours.
create policy "grrs visible with content" on grrs for select to authenticated
  using (
    (post_id is not null and exists (select 1 from posts p where p.id = post_id and can_view_post(auth.uid(), p.author_id)))
    or (photo_id is not null and can_view_photo(auth.uid(), photo_id))
  );
create policy "make grr" on grrs for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      (post_id is not null and exists (select 1 from posts p where p.id = post_id and can_view_post(auth.uid(), p.author_id)))
      or (photo_id is not null and can_view_photo(auth.uid(), photo_id))
    )
  );
create policy "remove own grr" on grrs for delete to authenticated using (user_id = auth.uid());

create policy "comments visible with content" on comments for select to authenticated
  using (
    (post_id is not null and exists (select 1 from posts p where p.id = post_id and can_view_post(auth.uid(), p.author_id)))
    or (photo_id is not null and can_view_photo(auth.uid(), photo_id))
  );
create policy "comment on visible content" on comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and (
      (post_id is not null and exists (select 1 from posts p where p.id = post_id and can_view_post(auth.uid(), p.author_id)))
      or (photo_id is not null and can_view_photo(auth.uid(), photo_id))
    )
  );
create policy "delete: author or content owner" on comments for delete to authenticated
  using (
    author_id = auth.uid()
    or exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid())
    or exists (select 1 from photos ph where ph.id = photo_id and ph.owner_id = auth.uid())
  );

create policy "own hidden posts" on hidden_posts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "file reports" on reports for insert to authenticated with check (reporter_id = auth.uid());

create policy "events for members" on events for select to authenticated
  using (creator_id = auth.uid() or is_event_member(id, auth.uid()));
create policy "create events" on events for insert to authenticated with check (creator_id = auth.uid());
create policy "creator edits" on events for update to authenticated using (creator_id = auth.uid());
create policy "creator deletes" on events for delete to authenticated using (creator_id = auth.uid());

create policy "members see members" on event_members for select to authenticated
  using (is_event_member(event_id, auth.uid()));
create policy "invite friends" on event_members for insert to authenticated
  with check (
    invited_by = auth.uid()
    and (user_id = auth.uid() or are_friends(auth.uid(), user_id))
    and (
      exists (select 1 from events e where e.id = event_id and e.creator_id = auth.uid())
      or exists (select 1 from event_members m where m.event_id = event_members.event_id and m.user_id = auth.uid() and m.status in ('going', 'maybe'))
    )
  );
create policy "answer own invitation" on event_members for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Conversations are created through start_conversation(); members read and write.
create policy "members read conversations" on conversations for select to authenticated
  using (is_conversation_member(id, auth.uid()));
create policy "members read membership" on conversation_members for select to authenticated
  using (is_conversation_member(conversation_id, auth.uid()));
create policy "mark own read" on conversation_members for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "members read messages" on messages for select to authenticated
  using (is_conversation_member(conversation_id, auth.uid()));
create policy "members send messages" on messages for insert to authenticated
  with check (sender_id = auth.uid() and is_conversation_member(conversation_id, auth.uid()));

create policy "own notifications" on notifications for select to authenticated using (user_id = auth.uid());
create policy "mark own notifications" on notifications for update to authenticated using (user_id = auth.uid());

-- =============================================================================
-- RPCs for multi-row operations
-- =============================================================================

create or replace function accept_friend_request(sender uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update friend_requests set status = 'accepted', responded_at = now()
  where from_id = sender and to_id = auth.uid() and status = 'pending';
  if not found then raise exception 'request not found'; end if;
  insert into friendships (user_a, user_b) values (least(sender, auth.uid()), greatest(sender, auth.uid()))
  on conflict do nothing;
end;
$$;

-- Removes the photo from the caller's profile. It is deleted only when no owner
-- is left; if the uploader leaves, the next owner takes it into their wall album.
create or replace function leave_photo(photo uuid) returns text
language plpgsql security definer set search_path = public as $
declare
  ph photos;
  heir uuid;
begin
  select * into ph from photos where id = photo;
  if ph is null or not is_photo_owner(auth.uid(), photo) then raise exception 'not an owner'; end if;

  if ph.owner_id <> auth.uid() then
    delete from photo_owners where photo_id = photo and user_id = auth.uid();
    return 'left';
  end if;

  select user_id into heir from photo_owners
  where photo_id = photo and status = 'accepted' order by responded_at limit 1;
  if heir is null then
    delete from photos where id = photo;
    return 'deleted';
  end if;

  update albums set cover_photo_id = null where cover_photo_id = photo;
  update photos
     set owner_id = heir,
         album_id = (select id from albums where owner_id = heir and kind = 'wall')
   where id = photo;
  delete from photo_owners where photo_id = photo and user_id = heir;
  return 'left';
end;
$;

-- Counts a visit to someone else's profile (not your own, once per day).
create or replace function register_visit(profile uuid) returns int
language plpgsql security definer set search_path = public as $
declare
  counted int;
begin
  if profile <> auth.uid() and can_view_profile(auth.uid(), profile) then
    insert into profile_visits (profile_id, visitor_id) values (profile, auth.uid()) on conflict do nothing;
    get diagnostics counted = row_count;
    if counted > 0 then update profiles set visit_count = visit_count + 1 where id = profile; end if;
  end if;
  return (select visit_count from profiles where id = profile);
end;
$;

create or replace function start_conversation(other uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  conv uuid;
begin
  select cm1.conversation_id into conv
  from conversation_members cm1
  join conversation_members cm2 on cm2.conversation_id = cm1.conversation_id
  where cm1.user_id = auth.uid() and cm2.user_id = other
  limit 1;
  if conv is not null then return conv; end if;
  if not are_friends(auth.uid(), other) then raise exception 'only friends'; end if;
  insert into conversations default values returning id into conv;
  insert into conversation_members (conversation_id, user_id, last_read_at) values (conv, auth.uid(), now()), (conv, other, null);
  return conv;
end;
$$;

-- "Cerca de ti": posts from people within radius_km of the caller's town, following
-- account privacy. Returns the town if allowed; otherwise the distance, if allowed.
-- Coordinates never leave the database.
create or replace function nearby_posts(radius_km int, before timestamptz default null, page_size int default 8)
returns table (post_id uuid, city text, distance_km int)
language sql stable security definer set search_path = public as $
  with me as (select city_lat, city_lng from profiles where id = auth.uid())
  select p.id,
         case when can_view_city(auth.uid(), a.id) then a.city end,
         case when not can_view_city(auth.uid(), a.id) and can_view_distance(auth.uid(), a.id)
              then round(distance_km(me.city_lat, me.city_lng, a.city_lat, a.city_lng))::int end
  from posts p
  join profiles a on a.id = p.author_id
  cross join me
  where radius_km in (10, 25, 50)
    and me.city_lat is not null and a.city_lat is not null
    and a.id <> auth.uid()
    and distance_km(me.city_lat, me.city_lng, a.city_lat, a.city_lng) <= radius_km
    and can_view_post(auth.uid(), a.id)
    and not exists (select 1 from hidden_posts h where h.user_id = auth.uid() and h.post_id = p.id)
    and (before is null or p.created_at < before)
  order by p.created_at desc
  limit page_size + 1;
$;

-- =============================================================================
-- Notifications: grouped counters on the home page. Pending things (messages,
-- requests, invitations) are counted from their tables; only comments, Grr,
-- tags and acceptances are stored here. Preferences apply when displaying.
-- =============================================================================

create or replace function push_notification(recipient uuid, actor uuid, kind notification_type, target uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  s user_settings;
begin
  if recipient = actor then return; end if;
  select * into s from user_settings where user_id = recipient;
  if (kind in ('grr_post', 'grr_photo') and not s.notify_grr)
     or (kind in ('comment_post', 'comment_photo') and not s.notify_comments)
     or (kind in ('friend_request', 'friend_accepted') and not s.notify_friend_requests)
     or (kind = 'event_invite' and not s.notify_events)
     or (kind = 'message' and not s.notify_messages)
     or (kind = 'photo_tag' and not s.notify_tags) then
    return;
  end if;
  insert into notifications (user_id, actor_id, type, target_id)
  values (recipient, actor, kind, target)
  on conflict (user_id, actor_id, type, target_id) do update set created_at = now(), read_at = null;
end;
$$;

-- Grr: notify only when it is made. Removing a Grr never notifies.
create or replace function on_grr_insert() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.post_id is not null then
    perform push_notification((select author_id from posts where id = new.post_id), new.user_id, 'grr_post', new.post_id);
  else
    perform push_notification((select owner_id from photos where id = new.photo_id), new.user_id, 'grr_photo', new.photo_id);
  end if;
  return new;
end;
$$;
create trigger grr_notify after insert on grrs for each row execute function on_grr_insert();

create or replace function on_comment_insert() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.post_id is not null then
    perform push_notification((select author_id from posts where id = new.post_id), new.author_id, 'comment_post', new.post_id);
  else
    perform push_notification((select owner_id from photos where id = new.photo_id), new.author_id, 'comment_photo', new.photo_id);
  end if;
  return new;
end;
$$;
create trigger comment_notify after insert on comments for each row execute function on_comment_insert();

create or replace function on_friend_request_change() returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Pending requests are counted from friend_requests; only acceptance is stored.
  if new.status = 'accepted' and old.status = 'pending' then
    perform push_notification(new.from_id, new.to_id, 'friend_accepted', new.to_id);
  end if;
  return new;
end;
$$;
create trigger friend_request_notify after update on friend_requests for each row execute function on_friend_request_change();

create or replace function on_message_insert() returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Unread messages are counted from last_read_at; no notification is stored.
  update conversations set updated_at = new.created_at where id = new.conversation_id;
  return new;
end;
$$;
create trigger message_notify after insert on messages for each row execute function on_message_insert();

create or replace function on_tag_insert() returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform push_notification(new.user_id, new.tagged_by, 'photo_tag', new.photo_id);
  return new;
end;
$$;
create trigger tag_notify after insert on photo_tags for each row execute function on_tag_insert();

-- New auth user → profile, settings and wall album.
create or replace function on_auth_user_created() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, first_name, last_name, city)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'first_name', ''), coalesce(new.raw_user_meta_data ->> 'last_name', ''), coalesce(new.raw_user_meta_data ->> 'city', ''));
  insert into user_settings (user_id) values (new.id);
  insert into albums (owner_id, kind, title, description) values (new.id, 'wall', 'Fotos del muro', 'Fotografías publicadas en el muro.');
  return new;
end;
$$;
create trigger auth_user_created after insert on auth.users for each row execute function on_auth_user_created();

-- =============================================================================
-- Storage: private "photos" bucket, files at <owner_id>/<file>
-- =============================================================================

insert into storage.buckets (id, name, public) values ('photos', 'photos', false) on conflict do nothing;

create policy "upload own photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete own photos" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "read photos you can see" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and can_view_profile(auth.uid(), ((storage.foldername(name))[1])::uuid));
