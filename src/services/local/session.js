import { ensure } from '@/services/errors'
import { STORAGE_KEYS } from '@/config/app'

const KEY = STORAGE_KEYS.session

export const getSessionUserId = () => {
  try {
    return localStorage.getItem(KEY)
  } catch {
    return null
  }
}

export const setSessionUserId = (id) => {
  try {
    localStorage.setItem(KEY, id)
  } catch {
    // Storage blocked: the session lasts until reload.
  }
}

export const clearSession = () => {
  try {
    localStorage.removeItem(KEY)
  } catch {
    // Nothing to clear.
  }
}

/** Equivalent to auth.uid() on the server: every service call is scoped to it. */
export const requireUserId = (db) => {
  const id = getSessionUserId()
  ensure(id && db.profiles.some((p) => p.id === id), 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
  return id
}
