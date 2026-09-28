import { ApiError, ensure } from '@/services/errors'
import { DATA_SOURCE, STORAGE_KEYS } from '@/config/app'

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
  // While moving to Supabase, sections still on the local backend must not show
  // demo data inside a real account.
  if (DATA_SOURCE === 'supabase') {
    throw new ApiError('not_available', 'Esta sección todavía no está conectada a Supabase.')
  }
  const id = getSessionUserId()
  ensure(id && db.profiles.some((p) => p.id === id), 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
  return id
}
