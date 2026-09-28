// Notifications as the classic Spanish social networks did them: no feed of
// "X did Y", just grouped counters on the home page ("3 mensajes nuevos").
// Each group links to where it is dealt with and disappears once visited or
// answered. Shared by both backends, which only gather the raw state:
//
// - Pending things are derived from the real state: unread conversations,
//   friend requests, event invitations, photo co-ownership invitations.
// - Things that need no answer (comments, Grr, tags, accepted requests) are
//   stored as notifications and marked read when their place is visited.

/** Stored notification groups, in display order. `list` is where visiting clears them. */
export const STORED_GROUPS = [
  { key: 'wall', types: ['wall_message'], pref: 'comments', one: 'mensaje nuevo en tu tablón', many: 'mensajes nuevos en tu tablón', single: 'wall', list: 'wall' },
  { key: 'comments_posts', types: ['comment_post'], pref: 'comments', one: 'comentario nuevo en tu actividad', many: 'comentarios nuevos en tu actividad', single: 'post', list: 'posts' },
  { key: 'comments_photos', types: ['comment_photo'], pref: 'comments', one: 'comentario nuevo en tus fotos', many: 'comentarios nuevos en tus fotos', single: 'photo', list: 'photos' },
  { key: 'grr_posts', types: ['grr_post'], pref: 'grr', one: 'Grr nuevo en tu actividad', many: 'Grr nuevos en tu actividad', single: 'post', list: 'posts' },
  { key: 'grr_photos', types: ['grr_photo'], pref: 'grr', one: 'Grr nuevo en tus fotos', many: 'Grr nuevos en tus fotos', single: 'photo', list: 'photos' },
  { key: 'tags', types: ['photo_tag'], pref: 'tags', one: 'etiqueta nueva en fotos', many: 'etiquetas nuevas en fotos', single: 'photo', list: 'tagged' },
  { key: 'owners_accepted', types: ['photo_owner_accepted'], pref: 'tags', one: 'amigo ha aceptado compartir tu foto', many: 'amigos han aceptado compartir tus fotos', single: 'photo', list: 'photos' },
  { key: 'friends_accepted', types: ['friend_accepted'], pref: 'friendRequests', one: 'petición de amistad aceptada', many: 'peticiones de amistad aceptadas', single: 'friends', list: 'friends' },
]

/** Notification types a visited place clears (all of them without a list). */
export const typesSeenAt = (list) =>
  (list ? STORED_GROUPS.filter((g) => g.list === list) : STORED_GROUPS).flatMap((g) => g.types)

/** Label without the number; the counter is rendered apart. */
const pick = (n, one, many) => (n === 1 ? one : many)

const listLink = (me, list) => {
  if (list === 'friends') return '/friends'
  if (list === 'wall') return `/profile/${me}`
  return `/profile/${me}?tab=${list}`
}

const singleLink = (me, kind, targetId) => {
  if (kind === 'post') return `/post/${targetId}`
  if (kind === 'photo') return `/photo/${targetId}`
  if (kind === 'wall') return listLink(me, 'wall')
  return listLink(me, 'friends')
}

const pendingGroups = ({ conversationIds, requestCount, invitationEventIds, sharePhotoIds }) => [
  {
    key: 'messages',
    pref: 'messages',
    count: conversationIds.length,
    label: pick(conversationIds.length, 'mensaje privado nuevo', 'mensajes privados nuevos'),
    link: conversationIds.length === 1 ? `/messages/${conversationIds[0]}` : '/messages',
  },
  {
    key: 'requests',
    pref: 'friendRequests',
    count: requestCount,
    label: pick(requestCount, 'petición de amistad', 'peticiones de amistad'),
    link: '/friends?tab=requests',
  },
  {
    key: 'events',
    pref: 'events',
    count: invitationEventIds.length,
    label: pick(invitationEventIds.length, 'invitación a un evento', 'invitaciones a eventos'),
    link: invitationEventIds.length === 1 ? `/events/${invitationEventIds[0]}` : '/events',
  },
  {
    key: 'shares',
    pref: 'tags',
    count: sharePhotoIds.length,
    label: pick(sharePhotoIds.length, 'invitación para compartir una foto', 'invitaciones para compartir fotos'),
    link: `/photo/${sharePhotoIds[0]}`,
  },
]

const storedGroups = (me, unread) =>
  STORED_GROUPS.map((group) => {
    const items = unread.filter((n) => group.types.includes(n.type))
    const targets = [...new Set(items.map((n) => n.targetId))]
    return {
      key: group.key,
      pref: group.pref,
      count: items.length,
      label: pick(items.length, group.one, group.many),
      // Your status and photo uploads have no list page: go to the newest one.
      link: targets.length === 1 || group.single === 'post' ? singleLink(me, group.single, targets[0]) : listLink(me, group.list),
    }
  })

/**
 * Grouped counters for the home page, respecting the user's preferences.
 * @param {{
 *   me: string,
 *   prefs: Record<string, boolean>,
 *   conversationIds: string[],
 *   requestCount: number,
 *   invitationEventIds: string[],
 *   sharePhotoIds: string[],
 *   unread: { type: string, targetId: string }[],
 * }} state
 */
export const buildSummary = (state) =>
  [...pendingGroups(state), ...storedGroups(state.me, state.unread)]
    .filter((g) => g.count > 0 && state.prefs[g.pref] !== false)
    .map(({ key, count, label, link }) => ({ key, count, label, link }))
