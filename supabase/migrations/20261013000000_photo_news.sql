-- Home counters about photos (comments, Grr, tags, accepted or pending shares):
-- when there are several, the app lists exactly those photos with who did what.
-- Nothing is marked as seen here; opening each photo does it.

create or replace function photo_news(kinds text[]) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select yg_me() as id),
  items as (
    select n.target_id as photo_id, n.type::text as type, n.actor_id as actor, n.created_at
    from notifications n, me
    where n.user_id = me.id and n.read_at is null
      and n.type::text = any(kinds) and n.type <> 'photo_owner_invite'
    union all
    -- Pending share invitations are answered on the photo itself.
    select o.photo_id, 'photo_owner_invite', o.invited_by, o.created_at
    from photo_owners o, me
    where 'photo_owner_invite' = any(kinds) and o.user_id = me.id and o.status = 'pending'
  )
  select coalesce(jsonb_agg(t.block order by t.last_at desc), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'photo', jsonb_build_object(
        'id', p.id, 'storage_path', p.storage_path, 'width', p.width, 'height', p.height,
        'caption', p.caption, 'album_title', coalesce(a.title, '')
      ),
      'items', jsonb_agg(
        jsonb_build_object('type', i.type, 'actor', person_summary(i.actor), 'created_at', i.created_at)
        order by i.created_at desc
      )
    ) as block,
    max(i.created_at) as last_at
    from items i
    join photos p on p.id = i.photo_id
    left join albums a on a.id = p.album_id
    group by p.id, p.storage_path, p.width, p.height, p.caption, a.title
  ) t;
$$;

grant execute on function photo_news(text[]) to authenticated;
