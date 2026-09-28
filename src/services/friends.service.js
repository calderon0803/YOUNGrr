// Chooses the backend for friends (see auth.service.js).
import { localFriendsService } from '@/services/local/friends.local'
import { supabaseFriendsService } from '@/services/supabase/friends.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const friendsService = isLocalBackend ? localFriendsService : supabaseFriendsService
