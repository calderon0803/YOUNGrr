export const DATA_SOURCE = import.meta.env.VITE_DATA_SOURCE ?? 'local'

/** Public Supabase settings: the anon key is safe in the browser, RLS protects the data. */
export const SUPABASE = {
  url: import.meta.env.VITE_SUPABASE_URL ?? '',
  anonKey: import.meta.env.VITE_SUPABASE_ANON_KEY ?? '',
}

/** Private photos are served through signed URLs valid for this long. */
export const PHOTO_URL_TTL_S = 60 * 60

export const STORAGE_KEYS = {
  // Bumped when the demo dataset changes shape, so old local data is re-seeded.
  db: 'youngrr:db:v11',
  session: 'youngrr:session',
  theme: 'youngrr:theme',
}

/** Browser chrome color per theme (matches $blue-600 / $blue-850). */
export const THEME_COLORS = { light: '#2350a0', dark: '#142a57' }

export const FEED_PAGE_SIZE = 8
export const COMMENT_PREVIEW = 3
export const BADGE_POLL_INTERVAL_MS = 30_000
export const TOAST_DURATION_MS = 3200
export const GRR_TOAST_DURATION_MS = 1800
export const SEARCH_DEBOUNCE_MS = 250

/** "Cerca de ti" feed. */
export const NEARBY_RADII_KM = [10, 25, 50]
export const NEARBY_DEFAULT_RADIUS_KM = 25

/** OpenStreetMap geocoding (Nominatim). Its usage policy allows 1 request per second. */
export const GEOCODER = {
  url: 'https://nominatim.openstreetmap.org/search',
  minIntervalMs: 1100,
  debounceMs: 450,
  limit: 6,
}

export const IMAGE = {
  maxSide: 1600,
  avatarMaxSide: 600,
  quality: 0.82,
  maxBytes: 20 * 1024 * 1024,
  acceptedTypes: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
}

export const TEXT_LIMITS = {
  postText: 2000,
  commentText: 500,
  messageText: 2000,
  name: 40,
  city: 60,
  bio: 300,
  about: 80,
  albumTitle: 60,
  albumDescription: 300,
  caption: 200,
  eventTitle: 80,
  eventDescription: 1500,
  eventLocation: 120,
  passwordMin: 8,
}

export const REPORT_REASONS = [
  'Es spam',
  'Contenido ofensivo',
  'Acoso o intimidación',
  'Información falsa',
  'Otro motivo',
]
