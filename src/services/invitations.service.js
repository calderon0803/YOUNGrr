// Chooses the backend for invitations (see auth.service.js).
import { localInvitationsService } from '@/services/local/invitations.local'
import { supabaseInvitationsService } from '@/services/supabase/invitations.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const invitationsService = isLocalBackend ? localInvitationsService : supabaseInvitationsService
