// Chooses the auth backend: Supabase when VITE_DATA_SOURCE=supabase, the local
// demo backend otherwise. Both expose the same interface.
import { localAuthService } from '@/services/local/auth.local'
import { supabaseAuthService } from '@/services/supabase/auth.supabase'
import { DATA_SOURCE } from '@/config/app'

export const isLocalBackend = DATA_SOURCE !== 'supabase'

export const authService = isLocalBackend ? localAuthService : supabaseAuthService
