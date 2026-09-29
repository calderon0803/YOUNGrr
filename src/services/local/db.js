// Local mock backend: the whole dataset lives in IndexedDB under one key.
// Tables mirror supabase/migrations so the service layer can later be pointed
// at a real backend without touching stores or components.
import { del, get, keys, set } from 'idb-keyval'
import { buildSeed } from '@/data/seed'
import { STORAGE_KEYS } from '@/config/app'
import { ensure } from '@/services/errors'

const KEY = STORAGE_KEYS.db
const KEY_PREFIX = KEY.replace(/v\d+$/, '')

let db = null
let loading = null
let storageAvailable = true

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
  db.wallMessages ??= []
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
