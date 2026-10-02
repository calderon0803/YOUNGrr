// Chooses the backend for experience and levels (see auth.service.js).
import { localXpService } from '@/services/local/xp.local'
import { supabaseXpService } from '@/services/supabase/xp.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const xpService = isLocalBackend ? localXpService : supabaseXpService
