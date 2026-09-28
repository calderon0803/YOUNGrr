// Chooses the backend for events (see auth.service.js).
import { localEventsService } from '@/services/local/events.local'
import { supabaseEventsService } from '@/services/supabase/events.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const eventsService = isLocalBackend ? localEventsService : supabaseEventsService
