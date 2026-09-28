// Chooses the backend for photos and albums (see auth.service.js).
import { localPhotosService } from '@/services/local/photos.local'
import { supabasePhotosService } from '@/services/supabase/photos.supabase'
import { isLocalBackend } from '@/services/auth.service'

export const photosService = isLocalBackend ? localPhotosService : supabasePhotosService
