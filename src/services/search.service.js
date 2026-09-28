// Chooses the backend for the global search (see auth.service.js).
import { localSearchService } from '@/services/local/search.local'
import { supabaseSearchService } from '@/services/supabase/search.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const searchService = isLocalBackend ? localSearchService : supabaseSearchService
