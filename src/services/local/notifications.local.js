// Home page counters for the local demo backend. Same interface as
// notifications.supabase.js; the groups are built in notifications.groups.js.
import { commit, getDb } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canSeeEvent } from '@/services/local/views'
import { settingsOf } from '@/services/local/access'
import { buildSummary, typesSeenAt } from '@/services/notifications.groups'
import { nowIso } from '@/utils/time'

const unreadConversationIds = (db, me) =>
  db.conversations
    .filter((c) => {
      if (!c.memberIds.includes(me)) return false
      const lastReadAt = db.conversationMembers.find((m) => m.conversationId === c.id && m.userId === me)?.lastReadAt
      return db.messages.some((m) => m.conversationId === c.id && m.senderId !== me && (!lastReadAt || m.createdAt > lastReadAt))
    })
    .map((c) => c.id)

export const localNotificationsService = {
  /** Grouped counters for the home page, respecting the user's preferences. */
  async getSummary() {
    const db = await getDb()
    const me = requireUserId(db)
    return buildSummary({
      me,
      prefs: settingsOf(db, me).notifications,
      conversationIds: unreadConversationIds(db, me),
      requestCount: db.friendRequests.filter((r) => r.toId === me && r.status === 'pending').length,
      invitationEventIds: db.eventMembers
        .filter((m) => m.userId === me && m.status === 'pending' && db.events.some((e) => e.id === m.eventId && canSeeEvent(db, me, e)))
        .map((m) => m.eventId),
      sharePhotoIds: db.photoOwners
        .filter((o) => o.userId === me && o.status === 'pending' && db.photos.some((p) => p.id === o.photoId))
        .map((o) => o.photoId),
      unread: db.notifications
        .filter((n) => n.userId === me && !n.readAt && db.profiles.some((p) => p.id === n.actorId))
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt)),
    })
  },

  /**
   * Marks as seen what a visited place shows: one target (a post or photo) or
   * a whole list (your posts, photos, tags, friends).
   * @param {{ targetId?: string, list?: 'wall' | 'posts' | 'photos' | 'tagged' | 'friends' }} place
   */
  async markSeen({ targetId = null, list = null }) {
    const db = await getDb()
    const me = requireUserId(db)
    const types = new Set(typesSeenAt(list))
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
