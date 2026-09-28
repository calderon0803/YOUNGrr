-- Home page counters ("Novedades"): the raw state the app groups into
-- counters, and marking stored notifications as seen when their place is visited.

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
    'unread', coalesce((
      select jsonb_agg(jsonb_build_object('type', n.type, 'target_id', n.target_id) order by n.created_at desc)
      from notifications n where n.user_id = me.id and n.read_at is null
    ), '[]'::jsonb)
  )
  from me;
$$;

-- Marks as read the caller's notifications of these types (only one target if given).
create or replace function mark_notifications_seen(kinds text[], target uuid default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare
  changed int;
begin
  update notifications set read_at = now()
  where user_id = yg_me() and read_at is null and type::text = any(kinds) and (target is null or target_id = target);
  get diagnostics changed = row_count;
  return changed > 0;
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array['notification_state()', 'mark_notifications_seen(text[], uuid)'] loop
    execute format('revoke execute on function %s from public', fn);
    execute format('revoke execute on function %s from anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;
