// Experience and levels for the local demo backend. Same interface as
// xp.supabase.js and the same rules as the levels migration: what you publish
// (and the Grr you receive) only counts if it is still there XP_MATURE_DAYS
// later, each thing once, with daily limits; experience is never lost.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewProfile } from '@/services/local/access'
import { checkAchievements } from '@/services/local/achievements.local'
import { ACHIEVEMENTS } from '@/config/achievements'
import { XP_MATURE_DAYS, levelForXp, xpForLevel } from '@/config/levels'
import { nowIso, toDateInput } from '@/utils/time'

const DAY_MS = 86_400_000
const LIMITS = { photo: 10, comment: 10, wall: 5, gallinero: 10, taste: 10, grr: 20, friend: 5 }
const TIER_XP = [10, 20, 30, 50]

const dayOf = (at) => toDateInput(new Date(at))
const addDays = (day, n) => toDateInput(new Date(Date.parse(`${day}T12:00:00`) + n * DAY_MS))
const today = () => toDateInput(new Date())
/** Monday of the week of a day (friendships are limited by week). */
const weekOf = (day) => {
  const date = new Date(`${day}T12:00:00`)
  return addDays(day, -((date.getDay() + 6) % 7))
}

const tables = (db) => {
  db.xpLedger ??= []
  db.xpTotals ??= {}
  db.xpLogins ??= []
}

const earned = (db, person, source, ref) => db.xpLedger.some((l) => l.userId === person && l.source === source && l.ref === ref)

const give = (db, person, source, ref, amount, day) => {
  if (earned(db, person, source, ref)) return
  db.xpLedger.push({ userId: person, source, ref, amount, day, earnedAt: nowIso() })
}

/** What would give experience between two days, not counted yet, within the limits. */
const candidates = (db, person, d1, d2) => {
  const owner = (type, id) => (type === 'post' ? db.posts.find((p) => p.id === id)?.authorId : db.photos.find((p) => p.id === id)?.ownerId)
  const myGroupPosts = new Set(db.groupPosts.filter((p) => p.authorId === person).map((p) => p.id))
  const raw = [
    ...db.photos.filter((p) => p.ownerId === person).map((p) => ['photo', p.id, 2, p.createdAt]),
    ...db.comments.filter((c) => c.authorId === person && owner(c.targetType, c.targetId) && owner(c.targetType, c.targetId) !== person).map((c) => ['comment', c.id, 1, c.createdAt]),
    ...db.wallMessages.filter((w) => w.authorId === person && w.profileId !== person).map((w) => ['wall', w.id, 1, w.createdAt]),
    ...db.groupPosts.filter((p) => p.authorId === person).map((p) => ['gallinero', p.id, 1, p.createdAt]),
    ...db.groupReplies.filter((r) => r.authorId === person).map((r) => ['gallinero', r.id, 1, r.createdAt]),
    ...(db.tastes ?? []).filter((t) => t.userId === person).map((t) => ['taste', `${t.kind}:${t.source}:${t.externalId}`, 1, t.createdAt]),
    ...db.grrs.filter((g) => g.userId !== person && owner(g.targetType, g.targetId) === person).map((g) => ['grr', `${g.userId}:${g.targetId}`, 1, g.createdAt]),
    ...db.groupPostGrrs.filter((g) => g.userId !== person && myGroupPosts.has(g.postId)).map((g) => ['grr', `${g.userId}:${g.postId}`, 1, g.createdAt]),
    ...db.friendships.filter((f) => [f.userA, f.userB].includes(person)).map((f) => ['friend', f.userA === person ? f.userB : f.userA, 5, f.createdAt]),
  ]
    .map(([source, ref, amount, at]) => ({ source, ref, amount, at, day: dayOf(at) }))
    .filter((c) => c.day >= d1 && c.day <= d2 && !earned(db, person, c.source, c.ref))
    .sort((a, b) => a.at.localeCompare(b.at))
  const windowOf = (c) => (c.source === 'friend' ? weekOf(c.day) : c.day)
  const used = {}
  for (const l of db.xpLedger.filter((x) => x.userId === person && LIMITS[x.source])) {
    const key = `${l.source}|${l.source === 'friend' ? weekOf(l.day) : l.day}`
    used[key] = (used[key] ?? 0) + 1
  }
  return raw.filter((c) => {
    const key = `${c.source}|${windowOf(c)}`
    if ((used[key] ?? 0) >= LIMITS[c.source]) return false
    used[key] = (used[key] ?? 0) + 1
    return true
  })
}

/** Profile, invitations and achievements: given at once. */
const awardInstant = (db, person) => {
  const profile = db.profiles.find((p) => p.id === person)
  if (profile?.avatarUrl && profile.bio && profile.city) give(db, person, 'profile', 'profile', 20, today())
  for (const i of db.invitations.filter((x) => x.inviterId === person && x.usedBy)) give(db, person, 'invite', i.usedBy, 25, dayOf(i.usedAt ?? nowIso()))
  for (const a of (db.achievements ?? []).filter((x) => x.userId === person && !x.code.startsWith('nivel_'))) {
    const tiered = (ACHIEVEMENTS[a.code]?.thresholds.length ?? 1) > 1
    for (let t = 1; t <= a.level; t++) give(db, person, 'achievement', `${a.code}:${t}`, tiered ? TIER_XP[t - 1] : 20, dayOf(a.earnedAt))
  }
}

const refresh = (db, person) => {
  checkAchievements(db, person)
  awardInstant(db, person)
  const xp = db.xpLedger.filter((l) => l.userId === person).reduce((sum, l) => sum + l.amount, 0)
  const level = levelForXp(xp)
  const before = db.xpTotals[person]
  // A first total (the start of the system) is not announced.
  db.xpTotals[person] = { xp, level, levelSeen: before ? before.levelSeen : level }
  if (before?.level !== level) checkAchievements(db, person)
}

/** The nightly job of the database, done when needed. */
const mature = (db) => {
  tables(db)
  const until = addDays(today(), -XP_MATURE_DAYS)
  const from = db.xpMaturedUntil ? addDays(db.xpMaturedUntil, 1) : '2000-01-01'
  if (from > until) return
  for (const p of db.profiles.filter((x) => !x.needsSetup)) {
    for (const c of candidates(db, p.id, from, until)) give(db, p.id, c.source, c.ref, c.amount, c.day)
    refresh(db, p.id)
  }
  db.xpMaturedUntil = until
}

const streakOf = (db, person) => {
  const days = new Set(db.xpLogins.filter((l) => l.userId === person).map((l) => l.day))
  let n = 0
  while (days.has(addDays(today(), -n))) n += 1
  return n
}

const myXp = (db, me) => {
  refresh(db, me)
  const t = db.xpTotals[me]
  const pendingFrom = db.xpMaturedUntil ? addDays(db.xpMaturedUntil, 1) : addDays(today(), -(XP_MATURE_DAYS - 1))
  return {
    xp: t.xp,
    level: t.level,
    levelXp: xpForLevel(t.level),
    nextLevelXp: xpForLevel(t.level + 1),
    pending: candidates(db, me, pendingFrom, today()).reduce((sum, c) => sum + c.amount, 0),
    streak: streakOf(db, me),
  }
}

export const localXpService = {
  async mine() {
    const db = await getDb()
    const me = requireUserId(db)
    mature(db)
    const result = myXp(db, me)
    await commit()
    return result
  },

  /** Once a day: 1 point, and a bonus at 7 and 30 days in a row. */
  async recordVisit() {
    const db = await getDb()
    const me = requireUserId(db)
    mature(db)
    const day = today()
    if (!db.xpLogins.some((l) => l.userId === me && l.day === day)) {
      db.xpLogins.push({ userId: me, day })
      give(db, me, 'login', day, 1, day)
      const streak = streakOf(db, me)
      if (streak === 7) give(db, me, 'streak', `7:${day}`, 5, day)
      else if (streak === 30) give(db, me, 'streak', `30:${day}`, 20, day)
    }
    const result = myXp(db, me)
    await commit()
    return result
  },

  /** Someone's level, if you can see their profile (null otherwise). */
  async levelOf(userId) {
    await latency(40, 100)
    const db = await getDb()
    const me = requireUserId(db)
    mature(db)
    if (!canViewProfile(db, me, userId)) return null
    if (!db.xpTotals[userId]) refresh(db, userId)
    return db.xpTotals[userId]?.level ?? 1
  },

  async markLevelSeen() {
    const db = await getDb()
    const me = requireUserId(db)
    tables(db)
    if (db.xpTotals[me]) db.xpTotals[me].levelSeen = db.xpTotals[me].level
    await commit()
  },
}

/** For the counters in Inicio: a level not announced yet (or null). */
const REMOVED_SOURCE = { photo: 'photo', comment: 'comment', wall_message: 'wall', group_post: 'gallinero', group_reply: 'gallinero' }

/** A removal by the moderators takes away what that content gave (and its Grr). */
export const loseRemovedXp = (db, owner, kind, id) => {
  const source = REMOVED_SOURCE[kind]
  if (!source || !owner) return
  tables(db)
  const before = db.xpLedger.length
  db.xpLedger = db.xpLedger.filter(
    (l) => !(l.userId === owner && ((l.source === source && l.ref === id) || (l.source === 'grr' && l.ref.endsWith(`:${id}`)))),
  )
  if (db.xpLedger.length !== before) refresh(db, owner)
}

export const pendingLevelUp = (db, me) => {
  const t = db.xpTotals?.[me]
  return t && t.level > t.levelSeen ? t.level : null
}
