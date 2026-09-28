import { createClient } from '@supabase/supabase-js'
import { SUPABASE } from '@/config/app'
import { ApiError } from '@/services/errors'

let client = null

/** Lazily created so the local demo backend never needs Supabase settings. */
export const getSupabase = () => {
  if (client) return client
  if (!SUPABASE.url || !SUPABASE.anonKey) {
    throw new ApiError('network', 'Falta la configuración de Supabase (VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY).')
  }
  client = createClient(SUPABASE.url, SUPABASE.anonKey, {
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
