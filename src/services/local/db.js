// Local mock backend: the whole dataset lives in IndexedDB under one key.
// Tables mirror supabase/migrations so the service layer can later be pointed
// at a real backend without touching stores or components.
import { del, get, keys, set } from 'idb-keyval'
import { buildSeed } from '@/data/seed'
import { DEFAULT_ALBUM_TITLE, STORAGE_KEYS } from '@/config/app'
import { ensure } from '@/services/errors'

const KEY = STORAGE_KEYS.db
const KEY_PREFIX = KEY.replace(/v\d+$/, '')

let db = null
let loading = null
let storageAvailable = true

/**
 * Every photo lives in its owner's "Mis fotos"; the other albums only list the
 * photos added to them (same change as the default_album migration).
 */
const toDefaultAlbums = (db) => {
  db.albumPhotos = []
  const mine = (ownerId) => {
    let album = db.albums.find((a) => a.ownerId === ownerId && a.kind === 'wall')
    if (!album) {
      album = { id: `wall_${ownerId}`, ownerId, kind: 'wall', title: DEFAULT_ALBUM_TITLE, description: '', coverPhotoId: null, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() }
      db.albums.push(album)
    }
    return album
  }
  for (const album of db.albums) if (album.kind === 'wall') Object.assign(album, { title: DEFAULT_ALBUM_TITLE, description: '' })
  for (const photo of db.photos) {
    const album = db.albums.find((a) => a.id === photo.albumId)
    if (album?.kind === 'user') {
      db.albumPhotos.push({ albumId: album.id, photoId: photo.id, addedAt: photo.createdAt })
      photo.albumId = mine(photo.ownerId).id
    }
  }
}

const load = async () => {
  let stored = null
  try {
    stored = await get(KEY)
  } catch {
    // Private mode or blocked storage: keep working in memory.
    storageAvailable = false
  }
  db = stored ?? buildSeed()
  // Tables added after a dataset was saved.
  db.photoOwners ??= []
  delete db.profileVisits
  db.moderators ??= []
  db.blocks ??= []
  db.wallMessages ??= []
  db.achievements ??= []
  db.moderationRemovals ??= []
  for (const table of ['groups', 'groupMembers', 'groupInvites', 'groupJoinRequests', 'groupPosts', 'groupReplies', 'groupPostGrrs', 'groupNotices', 'placeRequests', 'tastes', 'xpLedger', 'xpLogins']) db[table] ??= []
  db.xpTotals ??= {}
  if (!db.albumPhotos) toDefaultAlbums(db)
  db.conversationInvites ??= []
  for (const s of Object.values(db.settings)) s.groups ??= { profileShare: 'basic', notify: 'all', invites: 'friends' }
  if (!stored) {
    await commit()
    await dropOldVersions()
  }
  return db
}

/** Removes datasets saved under previous keys (youngrr:db:v1, v2...). */
const dropOldVersions = async () => {
  try {
    const old = (await keys()).filter((k) => typeof k === 'string' && k.startsWith(KEY_PREFIX) && k !== KEY)
    await Promise.all(old.map((k) => del(k)))
  } catch {
    // Not critical.
  }
}

// YOUNGrr has no offline mode: like a real server, the backend needs a connection.
const ensureOnline = () =>
  ensure(typeof navigator === 'undefined' || navigator.onLine, 'network', 'No hay conexión a internet. Conéctate para usar YOUNGrr.')

export const getDb = () => {
  ensureOnline()
  if (db) return Promise.resolve(db)
  loading ??= load()
  return loading
}

export const commit = async () => {
  if (!storageAvailable || !db) return
  try {
    await set(KEY, db)
  } catch {
    storageAvailable = false
  }
}

export const resetDb = async () => {
  try {
    await del(KEY)
  } catch {
    // Nothing stored.
  }
  db = buildSeed()
  loading = null
  await commit()
}

/** Simulated network latency, so loading states are real. */
export const latency = (min = 120, max = 320) => {
  return new Promise((resolve) => setTimeout(resolve, min + Math.random() * (max - min)))
}
