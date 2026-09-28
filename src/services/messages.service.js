// Chooses the backend for private messages (see auth.service.js).
import { localMessagesService } from '@/services/local/messages.local'
import { supabaseMessagesService } from '@/services/supabase/messages.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const messagesService = isLocalBackend ? localMessagesService : supabaseMessagesService
