// Achievements for the local demo backend. Same interface as
// achievements.supabase.js and the same rules as yg_achievement_metric().
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewProfile, friendIdsOf } from '@/services/local/access'
import { ensure } from '@/services/errors'
import { ACHIEVEMENTS, ACHIEVEMENT_SHARE_DAYS } from '@/config/achievements'
import { nowIso, toDateInput } from '@/utils/time'

const DAY_MS = 86_400_000

const going = (db, eventId) => db.eventMembers.filter((m) => m.eventId === eventId && m.status === 'going').length

/** How far a person has got in one achievement. */
const metric = (db, person, code) => {
  const today = toDateInput(new Date())
  const myPhotos = db.photos.filter((p) => p.ownerId === person)
  const myEvents = db.events.filter((e) => e.creatorId === person)
  switch (code) {
    // Every demo account is from before version 1.0.
    case 'fundador':
      return 1
    case 'primeros_pasos': {
      const profile = db.profiles.find((p) => p.id === person)
      return profile?.avatarUrl && !profile.needsSetup ? 1 : 0
    }
    case 'estreno':
    case 'fotografo':
      return myPhotos.length
    case 'anfitrion':
      return db.invitations.filter((i) => i.inviterId === person && i.usedBy).length
    case 'cuadrilla':
      return friendIdsOf(db, person).length
    case 'organizador':
      return myEvents.filter((e) => e.date < today && going(db, e.id) >= 3).length
    case 'fomo':
      return db.eventMembers.filter((m) => {
        const event = db.events.find((e) => e.id === m.eventId)
        return m.userId === person && m.status === 'going' && event && event.creatorId !== person && event.date < today
      }).length
    case 'planazo':
      return myEvents.some((e) => going(db, e.id) >= 10) ? 1 : 0
    case 'album_oro':
      return db.albums.some((a) => a.ownerId === person && a.kind === 'user' && db.albumPhotos.filter((ap) => ap.albumId === a.id).length >= 20) ? 1 : 0
    case 'paparazzi':
      return new Set(db.photoTags.filter((t) => t.taggedBy === person && t.userId !== person).map((t) => t.userId)).size
    case 'grrrr': {
      const statuses = new Set(db.posts.filter((p) => p.authorId === person && (p.kind ?? 'status') === 'status').map((p) => p.id))
      const photos = new Set(myPhotos.map((p) => p.id))
      return db.grrs.filter((g) => g.userId !== person && ((g.targetType === 'post' && statuses.has(g.targetId)) || (g.targetType === 'photo' && photos.has(g.targetId)))).length
    }
    case 'buen_rollo':
      return new Set(db.wallMessages.filter((w) => w.authorId === person && w.profileId !== person).map((w) => w.profileId)).size
    // Level titles: the level of the person (see xp.local.js).
    case 'nivel_5':
    case 'nivel_10':
    case 'nivel_20':
    case 'nivel_30':
    case 'nivel_50':
      return db.xpTotals?.[person]?.level ?? 1
    default:
      return 0
  }
}

/** Awards what a person has earned; a new level starts a new share window. */
export const checkAchievements = (db, person, { shareable = true } = {}) => {
  db.achievements ??= []
  for (const [code, def] of Object.entries(ACHIEVEMENTS)) {
    const reached = def.thresholds.filter((t) => t <= metric(db, person, code)).length
    if (!reached) continue
    const current = db.achievements.find((a) => a.userId === person && a.code === code)
    if (!current) db.achievements.push({ userId: person, code, level: reached, earnedAt: nowIso(), sharedAt: null, shareable })
    else if (current.level < reached) Object.assign(current, { level: reached, earnedAt: nowIso(), sharedAt: null, shareable })
  }
}

/** Like the migration: what everybody had already earned when achievements started is not announced. */
const start = (db) => {
  if (db.achievementsStarted) return
  for (const p of db.profiles) checkAchievements(db, p.id, { shareable: false })
  db.achievementsStarted = true
}

const shareUntil = (a) => new Date(Date.parse(a.earnedAt) + ACHIEVEMENT_SHARE_DAYS * DAY_MS).toISOString()

const mine = (db, me) =>
  Object.entries(ACHIEVEMENTS).map(([code, def]) => {
    const a = db.achievements.find((x) => x.userId === me && x.code === code)
    return {
      code,
      thresholds: def.thresholds,
      level: a?.level ?? 0,
      progress: metric(db, me, code),
      earnedAt: a?.earnedAt ?? null,
      sharedAt: a?.sharedAt ?? null,
      shareUntil: a && a.shareable !== false && !a.sharedAt ? shareUntil(a) : null,
      canShare: !!a && a.shareable !== false && !a.sharedAt && shareUntil(a) > nowIso(),
    }
  })

export const localAchievementsService = {
  /** All achievements with your level and progress (checks them first). */
  async mine() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    start(db)
    checkAchievements(db, me)
    await commit()
    return mine(db, me)
  },

  /** What someone has earned, if you can see their profile. */
  async forUser(userId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    if (!canViewProfile(db, me, userId)) return []
    start(db)
    return (db.achievements ?? [])
      .filter((a) => a.userId === userId)
      .sort((a, b) => b.earnedAt.localeCompare(a.earnedAt))
      .map(({ code, level, earnedAt }) => ({ code, level, earnedAt }))
  },

  /** Announces an achievement to your friends, within the share window. */
  async share(code) {
    await latency(80, 160)
    const db = await getDb()
    const me = requireUserId(db)
    const a = (db.achievements ?? []).find((x) => x.userId === me && x.code === code)
    ensure(a && a.shareable !== false && !a.sharedAt && shareUntil(a) > nowIso(), 'conflict', 'Este logro ya no se puede compartir.')
    a.sharedAt = nowIso()
    await commit()
    return mine(db, me)
  },
}
