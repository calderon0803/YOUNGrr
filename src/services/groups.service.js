// Chooses the backend for groups (see auth.service.js).
import { localGroupsService } from '@/services/local/groups.local'
import { supabaseGroupsService } from '@/services/supabase/groups.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const groupsService = isLocalBackend ? localGroupsService : supabaseGroupsService
