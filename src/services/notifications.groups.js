// Notifications as the classic Spanish social networks did them: no feed of
// "X did Y", just grouped counters on the home page ("3 mensajes nuevos").
// Each group links to where it is dealt with and disappears once visited or
// answered. Shared by both backends, which only gather the raw state:
//
// - Pending things are derived from the real state: unread conversations,
//   friend requests, event invitations, photo co-ownership invitations,
//   group invitations, requests to join your groups and group notices.
// - Things that need no answer (comments, Grr, tags, accepted requests) are
//   stored as notifications and marked read when their place is visited.

/** Stored notification groups, in display order. `list` is where visiting clears them. */
export const STORED_GROUPS = [
  { key: 'wall', types: ['wall_message'], pref: 'comments', one: 'mensaje nuevo en tu tablón', many: 'mensajes nuevos en tu tablón', single: 'wall', list: 'wall' },
  { key: 'comments_posts', types: ['comment_post'], pref: 'comments', one: 'comentario nuevo en tu estado', many: 'comentarios nuevos en tu estado', single: 'post', list: 'posts' },
  { key: 'comments_photos', types: ['comment_photo'], pref: 'comments', one: 'comentario nuevo en tus fotos', many: 'comentarios nuevos en tus fotos', single: 'photo', list: 'photos' },
  { key: 'grr_posts', types: ['grr_post'], pref: 'grr', one: 'Grr nuevo en tu estado', many: 'Grr nuevos en tu estado', single: 'post', list: 'posts' },
  { key: 'grr_photos', types: ['grr_photo'], pref: 'grr', one: 'Grr nuevo en tus fotos', many: 'Grr nuevos en tus fotos', single: 'photo', list: 'photos' },
  { key: 'tags', types: ['photo_tag'], pref: 'tags', one: 'etiqueta nueva en fotos', many: 'etiquetas nuevas en fotos', single: 'photo', list: 'tagged' },
  { key: 'owners_accepted', types: ['photo_owner_accepted'], pref: 'tags', one: 'amigo ha aceptado compartir tu foto', many: 'amigos han aceptado compartir tus fotos', single: 'photo', list: 'photos' },
  { key: 'friends_accepted', types: ['friend_accepted'], pref: 'friendRequests', one: 'petición de amistad aceptada', many: 'peticiones de amistad aceptadas', single: 'friends', list: 'friends' },
]

/** Photo groups that, when there are several, open the list of those photos. */
const PHOTO_NEWS = {
  ...Object.fromEntries(STORED_GROUPS.filter((g) => g.single === 'photo').map((g) => [g.key, g.types])),
  shares: ['photo_owner_invite'],
}

/** Types shown in the photo news list for a group key (null if it has none). */
export const photoNewsTypes = (key) => PHOTO_NEWS[key] ?? null

const photoNewsLink = (key) => `/photos/news?grupo=${key}`

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

const pendingGroups = ({ conversationIds, requestCount, invitationEventIds, sharePhotoIds, groupInviteIds = [], groupRequestIds = [], groupNoticeCount = 0 }) => [
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
    key: 'group_invites',
    pref: 'groups',
    count: groupInviteIds.length,
    label: pick(groupInviteIds.length, 'invitación a un grupo', 'invitaciones a grupos'),
    link: groupInviteIds.length === 1 ? `/groups/${groupInviteIds[0]}` : '/groups',
  },
  {
    key: 'group_requests',
    pref: 'groups',
    count: groupRequestIds.length,
    label: pick(groupRequestIds.length, 'solicitud para entrar en tus grupos', 'solicitudes para entrar en tus grupos'),
    link: new Set(groupRequestIds).size === 1 ? `/groups/${groupRequestIds[0]}?tab=people` : '/groups',
  },
  {
    key: 'group_notices',
    pref: 'groups',
    count: groupNoticeCount,
    label: pick(groupNoticeCount, 'aviso sobre tus grupos', 'avisos sobre tus grupos'),
    link: '/groups',
  },
  {
    key: 'shares',
    pref: 'tags',
    count: sharePhotoIds.length,
    label: pick(sharePhotoIds.length, 'invitación para compartir una foto', 'invitaciones para compartir fotos'),
    link: sharePhotoIds.length === 1 ? `/photo/${sharePhotoIds[0]}` : photoNewsLink('shares'),
  },
]

const linkFor = (me, group, targets) => {
  // Your status has no list page: go to the newest one.
  if (targets.length === 1 || group.single === 'post') return singleLink(me, group.single, targets[0])
  // Several photos: a list of exactly those, with who did what.
  if (group.single === 'photo') return photoNewsLink(group.key)
  return listLink(me, group.list)
}

const storedGroups = (me, unread) =>
  STORED_GROUPS.map((group) => {
    const items = unread.filter((n) => group.types.includes(n.type))
    const targets = [...new Set(items.map((n) => n.targetId))]
    return {
      key: group.key,
      pref: group.pref,
      count: items.length,
      label: pick(items.length, group.one, group.many),
      link: linkFor(me, group, targets),
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
 *   groupInviteIds?: string[],
 *   groupRequestIds?: string[],
 *   groupNoticeCount?: number,
 *   unread: { type: string, targetId: string }[],
 * }} state
 */
export const buildSummary = (state) =>
  [...pendingGroups(state), ...storedGroups(state.me, state.unread)]
    .filter((g) => g.count > 0 && state.prefs[g.pref] !== false)
    .map(({ key, count, label, link }) => ({ key, count, label, link }))
