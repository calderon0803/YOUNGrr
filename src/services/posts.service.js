// Chooses the backend for posts (see auth.service.js).
import { localPostsService } from '@/services/local/posts.local'
import { supabasePostsService } from '@/services/supabase/posts.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const postsService = isLocalBackend ? localPostsService : supabasePostsService
