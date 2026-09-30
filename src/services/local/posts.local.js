import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewCity, canViewDistance, canViewPhoto, canViewPost, canViewProfile, findOr404, friendIdsOf, profileOf } from '@/services/local/access'
import { dropNotifications } from '@/services/local/notify'
import { activityBlock, postView } from '@/services/local/views'
import { ensure, ensureAccess, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso, toDateInput } from '@/utils/time'
import { ACTIVITY_WINDOW_DAYS, FEED_PAGE_SIZE, NEARBY_DEFAULT_RADIUS_KM, NEARBY_RADII_KM } from '@/config/app'
import { distanceKm, hasLocation } from '@/utils/geo'

const DAY_MS = 86_400_000

const windowStart = () => new Date(Date.now() - ACTIVITY_WINDOW_DAYS * DAY_MS).toISOString()

/** One card per person and (local) day, newest first, one page after `before`. */
const pageOfDays = (events, before) => {
  const last = new Map()
  for (const { person, at } of events) {
    const key = `${person}|${toDateInput(new Date(at))}`
    if (!last.has(key) || at > last.get(key)) last.set(key, at)
  }
  const sorted = [...last.entries()]
    .filter(([, at]) => !before || at < before)
    .sort((a, b) => b[1].localeCompare(a[1]))
    .map(([key, at]) => {
      const [person, day] = key.split('|')
      const [y, m, d] = day.split('-').map(Number)
      return { person, day, at, from: new Date(y, m - 1, d).toISOString(), to: new Date(y, m - 1, d + 1).toISOString() }
    })
  return { cards: sorted.slice(0, FEED_PAGE_SIZE), hasMore: sorted.length > FEED_PAGE_SIZE }
}

const removePost = (db, postId) => {
  db.posts = db.posts.filter((p) => p.id !== postId)
  db.comments = db.comments.filter((c) => !(c.targetType === 'post' && c.targetId === postId))
  db.grrs = db.grrs.filter((g) => !(g.targetType === 'post' && g.targetId === postId))
  db.hiddenPosts = db.hiddenPosts.filter((h) => h.postId !== postId)
  dropNotifications(db, (n) => n.targetId === postId)
}

export const removePhotoCascade = (db, photoId) => {
  db.photos = db.photos.filter((p) => p.id !== photoId)
  db.comments = db.comments.filter((c) => !(c.targetType === 'photo' && c.targetId === photoId))
  db.grrs = db.grrs.filter((g) => !(g.targetType === 'photo' && g.targetId === photoId))
  db.photoTags = db.photoTags.filter((t) => t.photoId !== photoId)
  db.photoOwners = db.photoOwners.filter((o) => o.photoId !== photoId)
  for (const post of db.posts) if (post.photoId === photoId) post.photoId = null
  for (const album of db.albums) if (album.coverPhotoId === photoId) album.coverPhotoId = null
  dropNotifications(db, (n) => n.targetId === photoId)
}

// Status and friends' activity for the local demo backend. Same interface as
// posts.supabase.js. There are no free posts: each person has one status (a
// short phrase) and the rest of the activity comes from photos and friendships.
export const localPostsService = {
  /** One block per friend with activity in the last days, most recent first. */
  async getActivity({ before = null } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const since = windowStart()
    const friends = new Set(friendIdsOf(db, me))
    const events = [
      ...db.posts.filter((p) => friends.has(p.authorId) && p.createdAt >= since).map((p) => ({ person: p.authorId, at: p.createdAt })),
      ...db.friendships
        .filter((f) => f.createdAt >= since && ![f.userA, f.userB].includes(me))
        .flatMap((f) => [f.userA, f.userB].filter((id) => friends.has(id)).map((person) => ({ person, at: f.createdAt }))),
      ...db.photoTags
        .filter((t) => friends.has(t.userId) && t.createdAt >= since)
        .filter((t) => {
          const photo = db.photos.find((p) => p.id === t.photoId)
          return photo && canViewPhoto(db, me, photo)
        })
        .map((t) => ({ person: t.userId, at: t.createdAt })),
      ...(db.achievements ?? []).filter((a) => friends.has(a.userId) && a.sharedAt && a.sharedAt >= since).map((a) => ({ person: a.userId, at: a.sharedAt })),
    ]
    const { cards, hasMore } = pageOfDays(events, before)
    return {
      items: cards.map((c) => activityBlock(db, me, c.person, { since: c.from > since ? c.from : since, until: c.to, day: c.day, withSocial: true, lastActivityAt: c.at })),
      hasMore,
    }
  },

  /**
   * "Cerca de ti": status and album uploads of people whose town is within
   * `radiusKm`, if their profile is visible to you.
   */
  async getNearbyActivity({ before = null, radiusKm = NEARBY_DEFAULT_RADIUS_KM } = {}) {
    validate(NEARBY_RADII_KM.includes(radiusKm) ? null : 'Radio no válido.')
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const origin = profileOf(db, me)
    if (!hasLocation(origin)) return { items: [], hasMore: false, needsLocation: true, originCity: '' }

    const here = { lat: origin.cityLat, lng: origin.cityLng }
    const distances = new Map()
    for (const person of db.profiles) {
      if (person.id === me || !hasLocation(person) || !canViewProfile(db, me, person.id)) continue
      const km = distanceKm(here, { lat: person.cityLat, lng: person.cityLng })
      if (km <= radiusKm) distances.set(person.id, km)
    }
    const since = windowStart()
    const events = db.posts.filter((p) => distances.has(p.authorId) && p.createdAt >= since).map((p) => ({ person: p.authorId, at: p.createdAt }))
    const { cards, hasMore } = pageOfDays(events, before)
    // The town if the person allows it; otherwise, the approximate distance if
    // allowed. Never exact positions.
    const items = cards.map(({ person, day, at, from, to }) => {
      const showCity = canViewCity(db, me, person)
      return {
        ...activityBlock(db, me, person, { since: from > since ? from : since, until: to, day, withSocial: false, lastActivityAt: at }),
        nearby: {
          city: showCity ? profileOf(db, person).city : null,
          distanceKm: !showCity && canViewDistance(db, me, person) ? Math.round(distances.get(person)) : null,
        },
      }
    })
    return { items, hasMore, needsLocation: false, originCity: origin.city }
  },

  async getPost(postId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const post = findOr404(db.posts, (p) => p.id === postId, 'Esto ya no existe.')
    ensureAccess(canViewPost(db, me, post), post.authorId)
    return postView(db, me, post, { commentPreview: Infinity })
  },

  /** The new status replaces the previous one (with its comments and Grr). */
  async setStatus(text) {
    validate(rules.required(text, 'Tu estado'), rules.max(text, LIMITS.status, 'El estado'))
    await latency(150, 300)
    const db = await getDb()
    const me = requireUserId(db)
    for (const old of db.posts.filter((p) => p.authorId === me && (p.kind ?? 'status') === 'status')) removePost(db, old.id)
    const post = { id: uid('p'), authorId: me, kind: 'status', text: text.trim(), photoId: null, createdAt: nowIso(), updatedAt: null }
    db.posts.push(post)
    await commit()
    return postView(db, me, post)
  },

  /** Removes your status or one of your "ha subido N fotos" items. */
  async deletePost(postId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const post = findOr404(db.posts, (p) => p.id === postId, 'Esto ya no existe.')
    ensure(post.authorId === me, 'forbidden', 'Solo puedes eliminar lo tuyo.')
    removePost(db, postId)
    await commit()
  },

  async reportPost(postId, reason) {
    validate(rules.required(reason, 'El motivo'))
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    findOr404(db.posts, (p) => p.id === postId, 'Esto ya no existe.')
    db.reports.push({ id: uid('r'), reporterId: me, postId, reason, createdAt: nowIso() })
    if (!db.hiddenPosts.some((h) => h.userId === me && h.postId === postId)) db.hiddenPosts.push({ userId: me, postId })
    await commit()
  },
}
