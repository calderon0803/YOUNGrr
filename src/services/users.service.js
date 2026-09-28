// Chooses the backend for profiles and settings (see auth.service.js).
import { localUsersService } from '@/services/local/users.local'
import { supabaseUsersService } from '@/services/supabase/users.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const usersService = isLocalBackend ? localUsersService : supabaseUsersService
