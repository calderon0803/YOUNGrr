// Grr and comments, shared by posts and photos.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewPhoto, canViewPost, findOr404, photoOwnerIds, summaryOf } from '@/services/local/access'
import { dropNotifications, notify } from '@/services/local/notify'
import { commentsOf, grrState } from '@/services/local/views'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'

/** Checks the target exists and the user can see it; returns its owner ids. */
const resolveTarget = (db, me, targetType, targetId) => {
  if (targetType === 'post') {
    const post = findOr404(db.posts, (p) => p.id === targetId, 'Este estado ya no existe.')
    ensure(canViewPost(db, me, post), 'forbidden', 'No puedes ver este estado.')
    // "Ha subido N fotos" items are information only; each photo has its own.
    ensure((post.kind ?? 'status') === 'status', 'forbidden', 'Solo los estados admiten Grr y comentarios.')
    return [post.authorId]
  }
  const photo = findOr404(db.photos, (p) => p.id === targetId, 'Esta fotografía ya no existe.')
  ensure(canViewPhoto(db, me, photo), 'forbidden', 'No puedes ver esta fotografía.')
  return photoOwnerIds(db, photo)
}

// Grr and comments for the local demo backend. Same interface as interactions.supabase.js.
export const localInteractionsService = {
  /**
   * Makes (value = true) or removes (value = false) a Grr. Idempotent: the
   * unique (user, target) constraint means repeating it never duplicates.
   * @param {'post' | 'photo'} targetType
   */
  async setGrr(targetType, targetId, value) {
    await latency(80, 200)
    const db = await getDb()
    const me = requireUserId(db)
    const ownerIds = resolveTarget(db, me, targetType, targetId)
    const index = db.grrs.findIndex((g) => g.userId === me && g.targetType === targetType && g.targetId === targetId)

    if (value && index === -1) {
      db.grrs.push({ id: uid('g'), userId: me, targetType, targetId, createdAt: nowIso() })
      for (const userId of ownerIds) notify(db, { userId, actorId: me, type: targetType === 'post' ? 'grr_post' : 'grr_photo', targetId })
    } else if (!value && index !== -1) {
      // Removing a Grr never creates a notification.
      db.grrs.splice(index, 1)
    }
    await commit()
    return grrState(db, me, targetType, targetId)
  },

  async listGrrers(targetType, targetId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    resolveTarget(db, me, targetType, targetId)
    return db.grrs
      .filter((g) => g.targetType === targetType && g.targetId === targetId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map((g) => summaryOf(db, g.userId))
  },

  async listComments(targetType, targetId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    resolveTarget(db, me, targetType, targetId)
    return commentsOf(db, targetType, targetId)
  },

  async addComment(targetType, targetId, text) {
    validate(rules.required(text, 'El comentario'), rules.max(text, LIMITS.commentText, 'El comentario'))
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const ownerIds = resolveTarget(db, me, targetType, targetId)
    const comment = { id: uid('c'), targetType, targetId, authorId: me, text: text.trim(), createdAt: nowIso() }
    db.comments.push(comment)
    for (const userId of ownerIds) notify(db, { userId, actorId: me, type: targetType === 'post' ? 'comment_post' : 'comment_photo', targetId })
    await commit()
    return { ...comment, author: summaryOf(db, me) }
  },

  /** Authors can delete their comments; owners can delete comments on their content. */
  async deleteComment(commentId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const comment = findOr404(db.comments, (c) => c.id === commentId, 'Este comentario ya no existe.')
    const ownerIds = resolveTarget(db, me, comment.targetType, comment.targetId)
    ensure(comment.authorId === me || ownerIds.includes(me), 'forbidden', 'No puedes eliminar este comentario.')
    db.comments = db.comments.filter((c) => c.id !== commentId)

    const stillComments = db.comments.some(
      (c) => c.authorId === comment.authorId && c.targetType === comment.targetType && c.targetId === comment.targetId,
    )
    if (!stillComments) {
      dropNotifications(
        db,
        (n) => n.actorId === comment.authorId && n.targetId === comment.targetId && n.type.startsWith('comment_'),
      )
    }
    await commit()
  },
}
