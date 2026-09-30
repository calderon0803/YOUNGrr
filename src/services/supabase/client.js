import { createClient } from '@supabase/supabase-js'
import { SETUP_REQUIRED_EVENT, SUPABASE } from '@/config/app'
import { ApiError } from '@/services/errors'

let client = null

/** Lazily created so the local demo backend never needs Supabase settings. */
export const getSupabase = () => {
  if (client) return client
  if (!SUPABASE.url || !SUPABASE.anonKey) {
    throw new ApiError('network', 'Falta la configuración de Supabase (VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY).')
  }
  // Only the project's base address: the client adds /auth/v1, /rest/v1... itself.
  client = createClient(new URL(SUPABASE.url).origin, SUPABASE.anonKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  })
  return client
}

/** Same rule as the local backend: YOUNGrr has no offline mode. */
export const ensureOnline = () => {
  if (typeof navigator !== 'undefined' && !navigator.onLine) {
    throw new ApiError('network', 'No hay conexión a internet. Conéctate para usar YOUNGrr.')
  }
}

/** Turns a Supabase/PostgREST error into an ApiError with a Spanish message. */
export const toApiError = (error, fallback = 'Algo ha fallado. Inténtalo de nuevo.') => {
  if (error instanceof ApiError) return error
  if (typeof navigator !== 'undefined' && !navigator.onLine) {
    return new ApiError('network', 'No hay conexión a internet. Conéctate para usar YOUNGrr.')
  }
  return new ApiError('network', fallback)
}

// Database functions raise 'yg:<code>:<message>' with a message already written for the user.
const YG_ERROR = /^yg:([a-z_]+):(.+)$/s

/** Calls a database function (RPC) and returns its data, throwing ApiError on failure. */
export const rpc = async (name, args = {}, fallback) => {
  ensureOnline()
  const { data, error } = await getSupabase().rpc(name, args)
  if (error) {
    const match = YG_ERROR.exec(error.message ?? '')
    // Something is pending on the account (new terms, age...): the app takes the
    // person to the setup page instead of showing errors (see App.vue).
    if (match?.[1] === 'setup_required' && typeof window !== 'undefined') window.dispatchEvent(new CustomEvent(SETUP_REQUIRED_EVENT))
    // For inaccessible content the owner's id comes in the detail, to redirect to their profile.
    if (match) throw new ApiError(match[1], match[2], match[1] === 'forbidden' && error.details ? { ownerId: error.details } : {})
    throw toApiError(error, fallback)
  }
  return data
}

/** Current signed-in user id (Supabase Auth). */
export const currentUserId = async () => {
  const { data } = await getSupabase().auth.getUser()
  if (!data?.user) throw new ApiError('unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
  return data.user.id
}
