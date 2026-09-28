// Notifications as the classic Spanish social networks did them: no feed of
// "X did Y", just grouped counters on the home page ("3 mensajes nuevos").
// Each group links to where it is dealt with and disappears once visited or
// answered.
//
// - Pending things are derived from the real state: unread conversations,
//   friend requests, event invitations, photo co-ownership invitations.
// - Things that need no answer (comments, Grr, tags, accepted requests) are
//   stored in `notifications` and marked read when their place is visited.
import { commit, getDb } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canSeeEvent } from '@/services/local/views'
import { settingsOf } from '@/services/local/access'
import { nowIso } from '@/utils/time'

/** Stored notification groups, in display order. `list` is where visiting clears them. */
const STORED_GROUPS = [
  { key: 'comments_posts', types: ['comment_post'], pref: 'comments', one: 'comentario nuevo en tus publicaciones', many: 'comentarios nuevos en tus publicaciones', single: 'post', list: 'posts' },
  { key: 'comments_photos', types: ['comment_photo'], pref: 'comments', one: 'comentario nuevo en tus fotos', many: 'comentarios nuevos en tus fotos', single: 'photo', list: 'photos' },
  { key: 'grr_posts', types: ['grr_post'], pref: 'grr', one: 'Grr nuevo en tus publicaciones', many: 'Grr nuevos en tus publicaciones', single: 'post', list: 'posts' },
  { key: 'grr_photos', types: ['grr_photo'], pref: 'grr', one: 'Grr nuevo en tus fotos', many: 'Grr nuevos en tus fotos', single: 'photo', list: 'photos' },
  { key: 'tags', types: ['photo_tag'], pref: 'tags', one: 'etiqueta nueva en fotos', many: 'etiquetas nuevas en fotos', single: 'photo', list: 'tagged' },
  { key: 'owners_accepted', types: ['photo_owner_accepted'], pref: 'tags', one: 'amigo ha aceptado compartir tu foto', many: 'amigos han aceptado compartir tus fotos', single: 'photo', list: 'photos' },
  { key: 'friends_accepted', types: ['friend_accepted'], pref: 'friendRequests', one: 'petición de amistad aceptada', many: 'peticiones de amistad aceptadas', single: 'friends', list: 'friends' },
]

/** Label without the number; the counter is rendered apart. */
const pick = (n, one, many) => (n === 1 ? one : many)

const listLink = (me, list) => {
  if (list === 'friends') return '/friends'
  if (list === 'posts') return `/profile/${me}`
  return `/profile/${me}?tab=${list}`
}

const singleLink = (me, kind, targetId) => {
  if (kind === 'post') return `/post/${targetId}`
  if (kind === 'photo') return `/photo/${targetId}`
  return listLink(me, 'friends')
}

const unreadConversations = (db, me) =>
  db.conversations.filter((c) => {
    if (!c.memberIds.includes(me)) return false
    const lastReadAt = db.conversationMembers.find((m) => m.conversationId === c.id && m.userId === me)?.lastReadAt
    return db.messages.some((m) => m.conversationId === c.id && m.senderId !== me && (!lastReadAt || m.createdAt > lastReadAt))
  })

const pendingGroups = (db, me) => {
  const conversations = unreadConversations(db, me)
  const requests = db.friendRequests.filter((r) => r.toId === me && r.status === 'pending')
  const invitations = db.eventMembers.filter(
    (m) => m.userId === me && m.status === 'pending' && db.events.some((e) => e.id === m.eventId && canSeeEvent(db, me, e)),
  )
  const shares = db.photoOwners.filter((o) => o.userId === me && o.status === 'pending' && db.photos.some((p) => p.id === o.photoId))

  return [
    {
      key: 'messages',
      pref: 'messages',
      count: conversations.length,
      label: pick(conversations.length, 'mensaje privado nuevo', 'mensajes privados nuevos'),
      link: conversations.length === 1 ? `/messages/${conversations[0].id}` : '/messages',
    },
    {
      key: 'requests',
      pref: 'friendRequests',
      count: requests.length,
      label: pick(requests.length, 'petición de amistad', 'peticiones de amistad'),
      link: '/friends?tab=requests',
    },
    {
      key: 'events',
      pref: 'events',
      count: invitations.length,
      label: pick(invitations.length, 'invitación a un evento', 'invitaciones a eventos'),
      link: invitations.length === 1 ? `/events/${invitations[0].eventId}` : '/events',
    },
    {
      key: 'shares',
      pref: 'tags',
      count: shares.length,
      label: pick(shares.length, 'invitación para compartir una foto', 'invitaciones para compartir fotos'),
      link: `/photo/${shares[0]?.photoId}`,
    },
  ]
}

const storedGroups = (db, me) => {
  const unread = db.notifications.filter((n) => n.userId === me && !n.readAt && db.profiles.some((p) => p.id === n.actorId))
  return STORED_GROUPS.map((group) => {
    const items = unread.filter((n) => group.types.includes(n.type))
    const targets = [...new Set(items.map((n) => n.targetId))]
    return {
      key: group.key,
      pref: group.pref,
      count: items.length,
      label: pick(items.length, group.one, group.many),
      link: targets.length === 1 ? singleLink(me, group.single, targets[0]) : listLink(me, group.list),
    }
  })
}

export const notificationsService = {
  /** Grouped counters for the home page, respecting the user's preferences. */
  async getSummary() {
    const db = await getDb()
    const me = requireUserId(db)
    const prefs = settingsOf(db, me).notifications
    return [...pendingGroups(db, me), ...storedGroups(db, me)]
      .filter((g) => g.count > 0 && prefs[g.pref] !== false)
      .map(({ key, count, label, link }) => ({ key, count, label, link }))
  },

  /**
   * Marks as seen what a visited place shows: one target (a post or photo) or
   * a whole list (your posts, photos, tags, friends).
   * @param {{ targetId?: string, list?: 'posts' | 'photos' | 'tagged' | 'friends' }} place
   */
  async markSeen({ targetId = null, list = null }) {
    const db = await getDb()
    const me = requireUserId(db)
    const types = new Set(
      list ? STORED_GROUPS.filter((g) => g.list === list).flatMap((g) => g.types) : STORED_GROUPS.flatMap((g) => g.types),
    )
    let changed = false
    const now = nowIso()
    for (const n of db.notifications) {
      if (n.userId !== me || n.readAt || !types.has(n.type)) continue
      if (targetId && n.targetId !== targetId) continue
      n.readAt = now
      changed = true
    }
    if (changed) await commit()
    return changed
  },
}
