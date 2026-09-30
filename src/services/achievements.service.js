// Chooses the backend for achievements (see auth.service.js).
import { localAchievementsService } from '@/services/local/achievements.local'
import { supabaseAchievementsService } from '@/services/supabase/achievements.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const achievementsService = isLocalBackend ? localAchievementsService : supabaseAchievementsService
