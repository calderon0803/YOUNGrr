// Chooses the backend for tastes (see auth.service.js).
import { localTastesService } from '@/services/local/tastes.local'
import { supabaseTastesService } from '@/services/supabase/tastes.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const tastesService = isLocalBackend ? localTastesService : supabaseTastesService
