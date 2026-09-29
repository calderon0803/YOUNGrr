// Reports and moderation for the local demo backend. Same interface as
// moderation.supabase.js. The demo moderator is Carlos.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewPhoto, canViewPost, canViewProfile, summaryOf } from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { REPORT_REASONS } from '@/config/app'

const COLLECTIONS = { status: 'posts', photo: 'photos', comment: 'comments', wall_message: 'wallMessages', profile: 'profiles', message: 'messages' }

/** The reported content, if the reporter can see it: { ownerId, snapshot }. */
const findTarget = (db, me, kind, id) => {
  if (kind === 'status') {
    const post = db.posts.find((p) => p.id === id && canViewPost(db, me, p))
    return post && { ownerId: post.authorId, snapshot: { text: post.text } }
  }
  if (kind === 'photo') {
    const photo = db.photos.find((p) => p.id === id && canViewPhoto(db, me, p))
    return photo && { ownerId: photo.ownerId, snapshot: { text: photo.caption, photoUrl: photo.url } }
  }
  if (kind === 'comment') {
    const comment = db.comments.find((c) => c.id === id)
    return comment && { ownerId: comment.authorId, snapshot: { text: comment.text } }
  }
  if (kind === 'wall_message') {
    const message = db.wallMessages.find((w) => w.id === id && canViewProfile(db, me, w.profileId))
    return message && { ownerId: message.authorId, snapshot: { text: message.text } }
  }
  if (kind === 'message') {
    // Only a participant can report someone else's message.
    const message = db.messages.find((m) => m.id === id && !m.deleted)
    const member = message && db.conversations.find((c) => c.id === message.conversationId)?.memberIds.includes(me)
    return member && { ownerId: message.senderId, snapshot: { text: message.text } }
  }
  if (kind === 'profile') {
    const profile = db.profiles.find((p) => p.id === id)
    return profile && { ownerId: profile.id, snapshot: { name: `${profile.firstName} ${profile.lastName}`, text: profile.bio } }
  }
  return null
}

const requireModerator = (db, me) => ensure(db.moderators.includes(me), 'forbidden', 'No tienes acceso a la moderación.')

export const localModerationService = {
  async reportContent(kind, targetId, reason) {
    validate(REPORT_REASONS.includes(reason) ? null : 'Elige un motivo.')
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const target = findTarget(db, me, kind, targetId)
    ensure(target, 'not_found', 'Este contenido ya no existe.')
    ensure(target.ownerId !== me, 'validation', 'No puedes reportar tu propio contenido.')
    const open = db.reports.some((r) => r.reporterId === me && r.targetType === kind && r.targetId === targetId && r.status === 'pending')
    if (!open) {
      db.reports.push({
        id: uid('r'),
        reporterId: me,
        targetType: kind,
        targetId,
        targetOwnerId: target.ownerId,
        reason,
        snapshot: target.snapshot,
        status: 'pending',
        createdAt: nowIso(),
      })
    }
    // A reported status stops appearing for the reporter.
    if (kind === 'status' && !db.hiddenPosts.some((h) => h.userId === me && h.postId === targetId)) {
      db.hiddenPosts.push({ userId: me, postId: targetId })
    }
    await commit()
  },

  async isModerator() {
    const db = await getDb()
    return db.moderators.includes(requireUserId(db))
  },

  async listReports(filter = 'pending') {
    await latency()
    const db = await getDb()
    requireModerator(db, requireUserId(db))
    const person = (id) => (id && db.profiles.some((p) => p.id === id) ? summaryOf(db, id) : null)
    return db.reports
      .filter((r) => r.targetType && (filter === 'all' || r.status === filter))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map((r) => ({
        id: r.id,
        targetType: r.targetType,
        targetId: r.targetId,
        reason: r.reason,
        createdAt: r.createdAt,
        status: r.status,
        snapshot: { text: r.snapshot?.text ?? '', name: r.snapshot?.name ?? null, photoUrl: r.snapshot?.photoUrl ?? null },
        contentExists: db[COLLECTIONS[r.targetType]].some((x) => x.id === r.targetId),
        contentRemoved: !!r.contentRemoved,
        reporter: person(r.reporterId),
        targetOwner: person(r.targetOwnerId),
        resolvedBy: person(r.resolvedBy),
        resolvedAt: r.resolvedAt ?? null,
        resolutionNote: r.resolutionNote ?? '',
      }))
  },

  async resolveReport(reportId, decision, { removeContent = false, note = '' } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    requireModerator(db, me)
    const report = db.reports.find((r) => r.id === reportId)
    ensure(report, 'not_found', 'Este reporte ya no existe.')
    const remove = removeContent && decision === 'resolved'
    if (remove) {
      ensure(report.targetType !== 'profile', 'validation', 'Un perfil no se puede eliminar desde aquí.')
      if (report.targetType === 'message') {
        const message = db.messages.find((m) => m.id === report.targetId)
        if (message) Object.assign(message, { text: '', deleted: true, deletedAt: nowIso() })
      } else {
        const key = COLLECTIONS[report.targetType]
        db[key] = db[key].filter((x) => x.id !== report.targetId)
      }
    }
    // Every open report on the same content gets the same decision.
    for (const r of db.reports) {
      if (r.targetType === report.targetType && r.targetId === report.targetId && (r.id === reportId || r.status === 'pending')) {
        Object.assign(r, { status: decision, resolvedBy: me, resolvedAt: nowIso(), resolutionNote: note.trim(), contentRemoved: r.contentRemoved || remove })
      }
    }
    await commit()
  },
}
