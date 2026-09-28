-- Global search: people, events and albums, limited to what the caller can see.
create or replace function global_search(q text) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id), term as (select '%' || yg_fold(trim(q)) || '%' as pattern)
  select case when length(trim(coalesce(q, ''))) = 0
    then jsonb_build_object('people', '[]'::jsonb, 'events', '[]'::jsonb, 'albums', '[]'::jsonb)
    else jsonb_build_object(
      'people', search_people(q, 12),
      'events', coalesce((
        select jsonb_agg(event_json(me.id, e.id) order by e.date desc)
        from (
          select e.id, e.date from events e, me, term
          where (e.creator_id = me.id or is_event_member(e.id, me.id))
            and yg_fold(e.title || ' ' || e.location || ' ' || e.description) like term.pattern
          order by e.date desc limit 8
        ) e, me
      ), '[]'::jsonb),
      'albums', coalesce((
        select jsonb_agg(album_json(me.id, a.id) order by a.updated_at desc)
        from (
          select a.id, a.updated_at from albums a, me, term
          where a.kind = 'user' and can_view_profile(me.id, a.owner_id)
            and yg_fold(a.title || ' ' || a.description) like term.pattern
          order by a.updated_at desc limit 8
        ) a, me
      ), '[]'::jsonb)
    ) end
  from me;
$$;

revoke execute on function global_search(text) from public;
revoke execute on function global_search(text) from anon;
grant execute on function global_search(text) to authenticated;
