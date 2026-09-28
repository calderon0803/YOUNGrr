// Chooses the backend for profile walls (see auth.service.js).
import { localWallService } from '@/services/local/wall.local'
import { supabaseWallService } from '@/services/supabase/wall.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const wallService = isLocalBackend ? localWallService : supabaseWallService
