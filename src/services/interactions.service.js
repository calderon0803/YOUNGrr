// Chooses the backend for Grr and comments (see auth.service.js).
import { localInteractionsService } from '@/services/local/interactions.local'
import { supabaseInteractionsService } from '@/services/supabase/interactions.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const interactionsService = isLocalBackend ? localInteractionsService : supabaseInteractionsService
