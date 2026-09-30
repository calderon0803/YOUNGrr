// Home page counters for the local demo backend. Same interface as
// notifications.supabase.js; the groups are built in notifications.groups.js.
import { commit, getDb } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canSeeEvent } from '@/services/local/views'
import { isBlockedBetween, isGroupAdmin, settingsOf, summaryOf } from '@/services/local/access'
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

/** One entry per unseen mention in your groups (not in the ones you silenced). */
const groupMentionIds = (db, me) => {
  const ids = []
  for (const m of (db.groupMembers ?? []).filter((x) => x.userId === me && x.notify !== 'none')) {
    const posts = db.groupPosts.filter((p) => p.groupId === m.groupId)
    const postIds = new Set(posts.map((p) => p.id))
    const items = [...posts, ...db.groupReplies.filter((r) => postIds.has(r.postId))]
    const n = items.filter((x) => (x.mentions ?? []).includes(me) && x.createdAt > m.lastSeenAt && !isBlockedBetween(db, me, x.authorId)).length
    for (let i = 0; i < n; i++) ids.push(m.groupId)
  }
  return ids
}

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
      groupInviteIds: (db.groupInvites ?? []).filter((i) => i.userId === me && !isBlockedBetween(db, me, i.invitedBy)).map((i) => i.groupId),
      groupRequestIds: (db.groupJoinRequests ?? []).filter((r) => isGroupAdmin(db, r.groupId, me) && !isBlockedBetween(db, me, r.userId)).map((r) => r.groupId),
      groupNoticeCount: (db.groupNotices ?? []).filter((n) => n.userId === me).length,
      groupMentionIds: groupMentionIds(db, me),
      chatInviteIds: (db.conversationInvites ?? []).filter((i) => i.userId === me && !isBlockedBetween(db, me, i.invitedBy)).map((i) => i.conversationId),
      unread: db.notifications
        .filter((n) => n.userId === me && !n.readAt && db.profiles.some((p) => p.id === n.actorId))
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt)),
    })
  },

  /**
   * Photos behind the photo counters (unread comments, Grr, tags, accepted or
   * pending shares), newest first, with who did what. Marks nothing as seen.
   * @param {string[]} types
   */
  async getPhotoNews(types) {
    const db = await getDb()
    const me = requireUserId(db)
    const items = [
      ...db.notifications
        .filter((n) => n.userId === me && !n.readAt && types.includes(n.type) && n.type !== 'photo_owner_invite')
        .map((n) => ({ photoId: n.targetId, type: n.type, actorId: n.actorId, createdAt: n.createdAt })),
      ...(types.includes('photo_owner_invite')
        ? db.photoOwners
            .filter((o) => o.userId === me && o.status === 'pending')
            .map((o) => ({ photoId: o.photoId, type: 'photo_owner_invite', actorId: o.invitedBy, createdAt: o.createdAt }))
        : []),
    ]
    const byPhoto = new Map()
    for (const item of items.sort((a, b) => b.createdAt.localeCompare(a.createdAt))) {
      const photo = db.photos.find((p) => p.id === item.photoId)
      if (!photo) continue
      if (!byPhoto.has(photo.id)) {
        const album = db.albums.find((a) => a.id === photo.albumId)
        byPhoto.set(photo.id, {
          photo: { id: photo.id, url: photo.url, width: photo.width, height: photo.height, caption: photo.caption, albumTitle: album?.title ?? '' },
          items: [],
        })
      }
      byPhoto.get(photo.id).items.push({ type: item.type, actor: summaryOf(db, item.actorId), createdAt: item.createdAt })
    }
    return [...byPhoto.values()]
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
