// Chooses the backend for the home page counters (see auth.service.js).
import { localNotificationsService } from '@/services/local/notifications.local'
import { supabaseNotificationsService } from '@/services/supabase/notifications.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const notificationsService = isLocalBackend ? localNotificationsService : supabaseNotificationsService
