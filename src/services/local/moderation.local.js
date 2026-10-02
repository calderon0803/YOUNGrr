// Reports and moderation for the local demo backend. Same interface as
// moderation.supabase.js. The demo moderator is Carlos.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewPhoto, canViewPost, canViewProfile, groupMemberCount, isGroupMember, summaryOf } from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { APPEAL_DAYS, ILLEGAL_CATEGORIES, ILLEGAL_REASON, MODERATION_RULES, REPORT_REASONS, REPORT_THRESHOLD } from '@/config/app'

const COLLECTIONS = {
  status: 'posts',
  photo: 'photos',
  comment: 'comments',
  wall_message: 'wallMessages',
  profile: 'profiles',
  message: 'messages',
  group_post: 'groupPosts',
  group_reply: 'groupReplies',
}

const groupOfReply = (db, reply) => db.groupPosts.find((p) => p.id === reply?.postId)?.groupId
const groupName = (db, groupId) => db.groups.find((g) => g.id === groupId)?.name ?? ''

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
  if (kind === 'group_post') {
    // Members of the group only.
    const post = db.groupPosts.find((p) => p.id === id && isGroupMember(db, p.groupId, me))
    return post && { ownerId: post.authorId, snapshot: { text: post.text, photoUrl: post.photoUrl, group: groupName(db, post.groupId) } }
  }
  if (kind === 'group_reply') {
    const reply = db.groupReplies.find((r) => r.id === id && isGroupMember(db, groupOfReply(db, r), me))
    return reply && { ownerId: reply.authorId, snapshot: { text: reply.text, group: groupName(db, groupOfReply(db, reply)) } }
  }
  if (kind === 'profile') {
    const profile = db.profiles.find((p) => p.id === id)
    return profile && { ownerId: profile.id, snapshot: { name: `${profile.firstName} ${profile.lastName}`, text: profile.bio } }
  }
  return null
}

const DAY_MS = 86_400_000
const copy = (value) => structuredClone(value)

/** Everything that goes with a piece of content, to put it back later. */
const snapshotOf = (db, kind, id) => {
  const on = (type) => (x) => x.targetType === type && x.targetId === id
  if (kind === 'status') return { post: db.posts.find((p) => p.id === id), comments: db.comments.filter(on('post')), grrs: db.grrs.filter(on('post')) }
  if (kind === 'photo') {
    return {
      photo: db.photos.find((p) => p.id === id),
      owners: db.photoOwners.filter((o) => o.photoId === id),
      tags: db.photoTags.filter((t) => t.photoId === id),
      comments: db.comments.filter(on('photo')),
      grrs: db.grrs.filter(on('photo')),
      albums: db.albumPhotos.filter((ap) => ap.photoId === id),
      covers: db.albums.filter((a) => a.coverPhotoId === id).map((a) => a.id),
    }
  }
  if (kind === 'comment') return { comment: db.comments.find((c) => c.id === id) }
  if (kind === 'wall_message') return { wallMessage: db.wallMessages.find((w) => w.id === id) }
  if (kind === 'group_post') {
    return { groupPost: db.groupPosts.find((p) => p.id === id), replies: db.groupReplies.filter((r) => r.postId === id), grrs: db.groupPostGrrs.filter((g) => g.postId === id) }
  }
  if (kind === 'group_reply') return { groupReply: db.groupReplies.find((r) => r.id === id) }
  return { text: db.messages.find((m) => m.id === id)?.text ?? '' }
}

/** Takes the content (and what goes with it) out, as the database cascades. */
const takeOut = (db, kind, id) => {
  const notOn = (type) => (x) => !(x.targetType === type && x.targetId === id)
  if (kind === 'status') {
    db.posts = db.posts.filter((p) => p.id !== id)
    db.comments = db.comments.filter(notOn('post'))
    db.grrs = db.grrs.filter(notOn('post'))
  } else if (kind === 'photo') {
    db.photos = db.photos.filter((p) => p.id !== id)
    db.photoOwners = db.photoOwners.filter((o) => o.photoId !== id)
    db.photoTags = db.photoTags.filter((t) => t.photoId !== id)
    db.comments = db.comments.filter(notOn('photo'))
    db.grrs = db.grrs.filter(notOn('photo'))
    db.albumPhotos = db.albumPhotos.filter((ap) => ap.photoId !== id)
    for (const album of db.albums) if (album.coverPhotoId === id) album.coverPhotoId = null
  } else if (kind === 'comment') {
    db.comments = db.comments.filter((c) => c.id !== id)
  } else if (kind === 'wall_message') {
    db.wallMessages = db.wallMessages.filter((w) => w.id !== id)
  } else if (kind === 'message') {
    const message = db.messages.find((m) => m.id === id)
    if (message) Object.assign(message, { text: '', deleted: true, deletedAt: nowIso() })
  } else if (kind === 'group_post') {
    db.groupPosts = db.groupPosts.filter((p) => p.id !== id)
    db.groupReplies = db.groupReplies.filter((r) => r.postId !== id)
    db.groupPostGrrs = db.groupPostGrrs.filter((g) => g.postId !== id)
  } else if (kind === 'group_reply') {
    db.groupReplies = db.groupReplies.filter((r) => r.id !== id)
  }
}

/** Puts it back; false when it cannot be (a newer status, or its parent is gone). */
const putBack = (db, removal) => {
  const d = removal.data
  if (!d) return false
  if (removal.contentKind === 'status') {
    if (db.posts.some((p) => p.authorId === d.post.authorId && (p.kind ?? 'status') === 'status')) return false
    db.posts.push(d.post)
    db.comments.push(...d.comments)
    db.grrs.push(...d.grrs)
  } else if (removal.contentKind === 'photo') {
    db.photos.push(d.photo)
    db.photoOwners.push(...d.owners)
    db.photoTags.push(...d.tags)
    db.comments.push(...d.comments)
    db.grrs.push(...d.grrs)
    db.albumPhotos.push(...d.albums.filter((ap) => db.albums.some((a) => a.id === ap.albumId)))
    for (const album of db.albums) if (d.covers.includes(album.id) && !album.coverPhotoId) album.coverPhotoId = d.photo.id
  } else if (removal.contentKind === 'comment') {
    const parent = d.comment.targetType === 'post' ? db.posts : db.photos
    if (!parent.some((x) => x.id === d.comment.targetId)) return false
    db.comments.push(d.comment)
  } else if (removal.contentKind === 'wall_message') {
    db.wallMessages.push(d.wallMessage)
  } else if (removal.contentKind === 'group_post') {
    // Its group must still exist.
    if (!db.groups.some((g) => g.id === d.groupPost.groupId)) return false
    db.groupPosts.push(d.groupPost)
    db.groupReplies.push(...d.replies)
    db.groupPostGrrs.push(...d.grrs)
  } else if (removal.contentKind === 'group_reply') {
    if (!db.groupPosts.some((p) => p.id === d.groupReply.postId)) return false
    db.groupReplies.push(d.groupReply)
  } else {
    const message = db.messages.find((m) => m.id === removal.contentId)
    if (!message) return false
    Object.assign(message, { text: d.text, deleted: false, deletedAt: null })
  }
  return true
}

const person = (db, id) => (id && db.profiles.some((p) => p.id === id) ? summaryOf(db, id) : null)

// A message needs 1 report, or 2 in a chat of more than 5 people; in the
// Gallinero, 30% of the group's members (at least 3, at most 10).
const thresholdFor = (db, kind, targetId) => {
  if (kind === 'group_post' || kind === 'group_reply') {
    const groupId = kind === 'group_post' ? db.groupPosts.find((p) => p.id === targetId)?.groupId : groupOfReply(db, db.groupReplies.find((r) => r.id === targetId))
    return Math.max(3, Math.min(10, Math.ceil(0.3 * groupMemberCount(db, groupId))))
  }
  if (kind !== 'message') return REPORT_THRESHOLD
  const message = db.messages.find((m) => m.id === targetId)
  const size = db.conversations.find((c) => c.id === message?.conversationId)?.memberIds.length ?? 2
  return size > 5 ? 2 : 1
}

/** Reports grouped by content, newest group first; pending groups need the minimum. */
const reportGroups = (db, filter) => {
  const groups = new Map()
  for (const r of db.reports) {
    if (!r.targetType || (filter !== 'all' && r.status !== filter)) continue
    const key = `${r.targetType}:${r.targetId}`
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key).push(r)
  }
  return [...groups.values()]
    .map((g) => g.sort((a, b) => a.createdAt.localeCompare(b.createdAt)))
    .filter((g) => filter !== 'pending' || g.some((r) => r.illegal) || g.length >= thresholdFor(db, g[0].targetType, g[0].targetId))
    // Illegal content first.
    .sort((a, b) => Number(b.some((r) => r.illegal)) - Number(a.some((r) => r.illegal)) || b.at(-1).createdAt.localeCompare(a.at(-1).createdAt))
}

const noticeView = (r) => ({
  id: r.id,
  contentKind: r.contentKind,
  reason: r.reason,
  rule: r.rule ?? null,
  automated: false,
  removedAt: r.removedAt,
  appealUntil: r.appealUntil,
  canAppeal: !r.appealedAt && r.appealUntil > nowIso(),
  appealedAt: r.appealedAt,
  decision: r.decision,
  restored: r.restored,
})

const requireModerator = (db, me) => ensure(db.moderators.includes(me), 'forbidden', 'No tienes acceso a la moderación.')

export const localModerationService = {
  async reportContent(kind, targetId, reason, { illegalCategory = null, details = null } = {}) {
    const illegal = reason === ILLEGAL_REASON
    validate(
      REPORT_REASONS.includes(reason) || illegal ? null : 'Elige un motivo.',
      illegal && !ILLEGAL_CATEGORIES.some((c) => c.key === illegalCategory) ? 'Elige qué tipo de contenido ilegal es.' : null,
      illegal && (details ?? '').trim().length < 10 ? 'Explica por qué es ilegal.' : null,
    )
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const target = findTarget(db, me, kind, targetId)
    ensure(target, 'not_found', 'Este contenido ya no existe.')
    ensure(target.ownerId !== me, 'validation', 'No puedes reportar tu propio contenido.')
    const open = db.reports.find((r) => r.reporterId === me && r.targetType === kind && r.targetId === targetId && r.status === 'pending')
    // Reporting again as illegal upgrades the report you already sent.
    if (open && illegal) Object.assign(open, { illegal: true, illegalCategory, details: details.trim(), reason })
    if (!open) {
      db.reports.push({
        id: uid('r'),
        reporterId: me,
        targetType: kind,
        targetId,
        targetOwnerId: target.ownerId,
        reason,
        snapshot: target.snapshot,
        illegal,
        illegalCategory: illegal ? illegalCategory : null,
        details: illegal ? details.trim() : null,
        status: 'pending',
        createdAt: nowIso(),
      })
    }
    await commit()
  },

  /** Notices about your content removed by moderation, with the appeal state. */
  async myNotices() {
    const db = await getDb()
    const me = requireUserId(db)
    return db.moderationRemovals
      .filter((r) => r.ownerId === me && !r.noticeDismissedAt)
      .sort((a, b) => b.removedAt.localeCompare(a.removedAt))
      .map(noticeView)
  },

  /** Not while an appeal waits; before appealing, it gives the appeal up. */
  async dismissNotice(noticeId) {
    const db = await getDb()
    const me = requireUserId(db)
    const r = db.moderationRemovals.find((x) => x.id === noticeId && x.ownerId === me)
    if (r && !(r.appealedAt && !r.decision)) r.noticeDismissedAt = nowIso()
    await commit()
  },

  async appeal(noticeId, text) {
    validate(text.trim().length > 500 ? 'La explicación no puede superar los 500 caracteres.' : null)
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const r = db.moderationRemovals.find((x) => x.id === noticeId && x.ownerId === me)
    ensure(r && !r.appealedAt && !r.noticeDismissedAt && r.appealUntil > nowIso(), 'conflict', 'Ya no se puede apelar esta decisión.')
    Object.assign(r, { appealText: text.trim(), appealedAt: nowIso() })
    await commit()
    return db.moderationRemovals.filter((x) => x.ownerId === me && !x.noticeDismissedAt).map(noticeView)
  },

  async listAppeals() {
    await latency()
    const db = await getDb()
    requireModerator(db, requireUserId(db))
    return db.moderationRemovals
      .filter((r) => r.appealedAt && !r.decision)
      .sort((a, b) => a.appealedAt.localeCompare(b.appealedAt))
      .map((r) => {
        const d = r.data ?? {}
        return {
          id: r.id,
          contentKind: r.contentKind,
          reason: r.reason,
          owner: db.profiles.some((p) => p.id === r.ownerId) ? summaryOf(db, r.ownerId) : null,
          removedAt: r.removedAt,
          appealText: r.appealText,
          appealedAt: r.appealedAt,
          text: d.post?.text ?? d.photo?.caption ?? d.comment?.text ?? d.wallMessage?.text ?? d.groupPost?.text ?? d.groupReply?.text ?? d.text ?? '',
          photoUrl: d.photo?.url ?? d.groupPost?.photoUrl ?? null,
        }
      })
  },

  /** accept: the content goes back (if it can) and the owner is told. */
  async resolveAppeal(appealId, accept) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    requireModerator(db, me)
    const r = db.moderationRemovals.find((x) => x.id === appealId && x.appealedAt && !x.decision)
    ensure(r, 'not_found', 'Esta apelación ya no está pendiente.')
    const back = accept ? putBack(db, r) : false
    Object.assign(r, { decision: accept ? 'accepted' : 'rejected', restored: accept ? back : null, decidedBy: me, decidedAt: nowIso(), noticeDismissedAt: null })
    if (back) {
      r.data = null
      const report = db.reports.find((x) => x.id === r.reportId)
      if (report) report.contentRemoved = false
    }
    await commit()
    return { restored: back }
  },

  /** The demo keeps photos as data URLs: there are no files to delete. */
  async cleanUpRemovedFiles() {},

  async isModerator() {
    const db = await getDb()
    return db.moderators.includes(requireUserId(db))
  },

  /** One entry per reported content; pending ones only once they reach the minimum. */
  async listReports(filter = 'pending') {
    await latency()
    const db = await getDb()
    requireModerator(db, requireUserId(db))
    return reportGroups(db, filter).map((group) => {
      const newest = group.at(-1)
      const reasons = {}
      for (const r of group) reasons[r.reason] = (reasons[r.reason] ?? 0) + 1
      return {
        id: newest.id,
        targetType: newest.targetType,
        targetId: newest.targetId,
        reportCount: group.length,
        reasons,
        illegal: group.some((r) => r.illegal),
        illegalCategories: [...new Set(group.map((r) => r.illegalCategory).filter(Boolean))],
        details: group.map((r) => r.details).filter(Boolean).reverse(),
        createdAt: group[0].createdAt,
        lastReportedAt: newest.createdAt,
        status: newest.status,
        snapshot: { text: newest.snapshot?.text ?? '', name: newest.snapshot?.name ?? null, photoUrl: newest.snapshot?.photoUrl ?? null, group: newest.snapshot?.group ?? null },
        contentExists: db[COLLECTIONS[newest.targetType]].some((x) => x.id === newest.targetId),
        contentRemoved: group.some((r) => r.contentRemoved),
        targetOwner: person(db, newest.targetOwnerId),
        resolvedBy: person(db, newest.resolvedBy),
        resolvedAt: newest.resolvedAt ?? null,
        resolutionNote: newest.resolutionNote ?? '',
      }
    })
  },

  async pendingCount() {
    const db = await getDb()
    requireModerator(db, requireUserId(db))
    return reportGroups(db, 'pending').length + db.moderationRemovals.filter((r) => r.appealedAt && !r.decision).length
  },

  async resolveReport(reportId, decision, { removeContent = false, note = '', rule = null } = {}) {
    validate(removeContent && !MODERATION_RULES.some((r) => r.key === rule) ? 'Elige qué norma incumple.' : null)
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    requireModerator(db, me)
    const report = db.reports.find((r) => r.id === reportId)
    ensure(report, 'not_found', 'Este reporte ya no existe.')
    const remove = removeContent && decision === 'resolved'
    if (remove) {
      ensure(report.targetType !== 'profile', 'validation', 'Un perfil no se puede eliminar desde aquí.')
      // A copy is kept apart for the appeal, and its owner gets a notice (once).
      if (report.targetOwnerId && !report.contentRemoved) {
        const removedAt = nowIso()
        db.moderationRemovals.push({
          id: uid('mr'),
          reportId: report.id,
          ownerId: report.targetOwnerId,
          contentKind: report.targetType,
          contentId: report.targetId,
          reason: report.reason,
          rule,
          data: copy(snapshotOf(db, report.targetType, report.targetId)),
          removedAt,
          appealUntil: new Date(Date.parse(removedAt) + APPEAL_DAYS * DAY_MS).toISOString(),
          appealText: null,
          appealedAt: null,
          decision: null,
          restored: null,
          noticeDismissedAt: null,
        })
      }
      takeOut(db, report.targetType, report.targetId)
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
