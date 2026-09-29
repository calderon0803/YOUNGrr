// Chooses the backend for reports and moderation (see auth.service.js).
import { localModerationService } from '@/services/local/moderation.local'
import { supabaseModerationService } from '@/services/supabase/moderation.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const moderationService = isLocalBackend ? localModerationService : supabaseModerationService
