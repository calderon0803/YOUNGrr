import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'

export const notify = (db, { userId, actorId, type, targetId }) => {
  if (userId === actorId) return

  const existing = db.notifications.find(
    (n) => n.userId === userId && n.actorId === actorId && n.type === type && n.targetId === targetId,
  )
  if (existing) {
    existing.createdAt = nowIso()
    existing.readAt = null
    return
  }
  db.notifications.push({ id: uid('n'), userId, actorId, type, targetId, createdAt: nowIso(), readAt: null })
}

/** Removes notifications that point to deleted content. */
export const dropNotifications = (db, predicate) => {
  db.notifications = db.notifications.filter((n) => !predicate(n))
}
