import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewCity, canViewDistance, canViewPost, canViewProfile, findOr404, friendIdsOf, profileOf } from '@/services/local/access'
import { dropNotifications } from '@/services/local/notify'
import { postView } from '@/services/local/views'
import { ensure, ensureAccess, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { FEED_PAGE_SIZE, NEARBY_DEFAULT_RADIUS_KM, NEARBY_RADII_KM } from '@/config/app'
import { distanceKm, hasLocation } from '@/utils/geo'

const newestFirst = (a, b) => b.createdAt.localeCompare(a.createdAt)

const paginate = (db, me, posts, before) => {
  const sorted = posts.sort(newestFirst).filter((p) => !before || p.createdAt < before)
  return {
    items: sorted.slice(0, FEED_PAGE_SIZE).map((p) => postView(db, me, p)),
    hasMore: sorted.length > FEED_PAGE_SIZE,
  }
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

export const postsService = {
  /** Friends' activity (and your own), newest first. No strangers, no ranking. */
  async getFeed({ before = null } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const circle = new Set([me, ...friendIdsOf(db, me)])
    const hidden = new Set(db.hiddenPosts.filter((h) => h.userId === me).map((h) => h.postId))
    return paginate(db, me, db.posts.filter((p) => circle.has(p.authorId) && !hidden.has(p.id) && canViewPost(db, me, p)), before)
  },

  /**
   * "Cerca de ti": posts from people whose town is within `radiusKm`, visible
   * according to each author's account privacy. Newest first, no ranking.
   */
  async getNearbyFeed({ before = null, radiusKm = NEARBY_DEFAULT_RADIUS_KM } = {}) {
    validate(NEARBY_RADII_KM.includes(radiusKm) ? null : 'Radio no válido.')
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const origin = profileOf(db, me)
    if (!hasLocation(origin)) return { items: [], hasMore: false, needsLocation: true, originCity: '' }

    const here = { lat: origin.cityLat, lng: origin.cityLng }
    const distances = new Map()
    for (const person of db.profiles) {
      if (person.id === me || !hasLocation(person)) continue
      const km = distanceKm(here, { lat: person.cityLat, lng: person.cityLng })
      if (km <= radiusKm) distances.set(person.id, km)
    }

    const hidden = new Set(db.hiddenPosts.filter((h) => h.userId === me).map((h) => h.postId))
    const page = paginate(
      db,
      me,
      db.posts.filter((p) => distances.has(p.authorId) && !hidden.has(p.id) && canViewPost(db, me, p)),
      before,
    )
    // The town if the author allows it; otherwise, the approximate distance if allowed.
    // Never exact positions.
    const items = page.items.map((post) => {
      const showCity = canViewCity(db, me, post.authorId)
      return {
        ...post,
        nearby: {
          city: showCity ? profileOf(db, post.authorId).city : null,
          distanceKm: !showCity && canViewDistance(db, me, post.authorId) ? Math.round(distances.get(post.authorId)) : null,
        },
      }
    })
    return { ...page, items, needsLocation: false, originCity: origin.city }
  },

  async getUserPosts(userId, { before = null } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(canViewProfile(db, me, userId), 'forbidden', 'Este perfil es privado.')
    return paginate(db, me, db.posts.filter((p) => p.authorId === userId && canViewPost(db, me, p)), before)
  },

  async getPost(postId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const post = findOr404(db.posts, (p) => p.id === postId, 'Esta publicación ya no existe.')
    ensureAccess(canViewPost(db, me, post), post.authorId)
    return postView(db, me, post, { commentPreview: Infinity })
  },

  /** @param {{ text: string, photo?: { dataUrl: string, width: number, height: number } | null }} input */
  async createPost({ text, photo = null }) {
    validate(
      text.trim() || photo ? null : 'Escribe algo o añade una fotografía.',
      rules.max(text, LIMITS.postText, 'La publicación'),
    )
    await latency(200, 450)
    const db = await getDb()
    const me = requireUserId(db)
    const createdAt = nowIso()
    let photoId = null

    if (photo) {
      const wall = db.albums.find((a) => a.ownerId === me && a.kind === 'wall')
      ensure(wall, 'not_found', 'No se ha encontrado tu álbum del muro.')
      photoId = uid('ph')
      db.photos.push({ id: photoId, ownerId: me, albumId: wall.id, url: photo.dataUrl, width: photo.width, height: photo.height, caption: text.trim().slice(0, LIMITS.caption), createdAt })
      wall.updatedAt = createdAt
    }

    const post = { id: uid('p'), authorId: me, text: text.trim(), photoId, createdAt, updatedAt: null }
    db.posts.push(post)
    await commit()
    return postView(db, me, post)
  },

  async updatePost(postId, text) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const post = findOr404(db.posts, (p) => p.id === postId, 'Esta publicación ya no existe.')
    ensure(post.authorId === me, 'forbidden', 'Solo puedes editar tus publicaciones.')
    validate(
      text.trim() || post.photoId ? null : 'La publicación no puede quedar vacía.',
      rules.max(text, LIMITS.postText, 'La publicación'),
    )
    post.text = text.trim()
    post.updatedAt = nowIso()
    await commit()
    return postView(db, me, post)
  },

  async deletePost(postId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const post = findOr404(db.posts, (p) => p.id === postId, 'Esta publicación ya no existe.')
    ensure(post.authorId === me, 'forbidden', 'Solo puedes eliminar tus publicaciones.')

    db.posts = db.posts.filter((p) => p.id !== postId)
    db.comments = db.comments.filter((c) => !(c.targetType === 'post' && c.targetId === postId))
    db.grrs = db.grrs.filter((g) => !(g.targetType === 'post' && g.targetId === postId))
    db.hiddenPosts = db.hiddenPosts.filter((h) => h.postId !== postId)
    dropNotifications(db, (n) => n.targetId === postId)

    // A photo published from the wall goes away with its post.
    const photo = post.photoId ? db.photos.find((p) => p.id === post.photoId) : null
    const album = photo ? db.albums.find((a) => a.id === photo.albumId) : null
    if (photo && album?.kind === 'wall') removePhotoCascade(db, photo.id)
    await commit()
  },

  async hidePost(postId) {
    await latency(80, 160)
    const db = await getDb()
    const me = requireUserId(db)
    if (!db.hiddenPosts.some((h) => h.userId === me && h.postId === postId)) {
      db.hiddenPosts.push({ userId: me, postId })
    }
    await commit()
  },

  async unhidePost(postId) {
    const db = await getDb()
    const me = requireUserId(db)
    db.hiddenPosts = db.hiddenPosts.filter((h) => !(h.userId === me && h.postId === postId))
    await commit()
  },

  async reportPost(postId, reason) {
    validate(rules.required(reason, 'El motivo'))
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    findOr404(db.posts, (p) => p.id === postId, 'Esta publicación ya no existe.')
    db.reports.push({ id: uid('r'), reporterId: me, postId, reason, createdAt: nowIso() })
    if (!db.hiddenPosts.some((h) => h.userId === me && h.postId === postId)) db.hiddenPosts.push({ userId: me, postId })
    await commit()
  },
}
