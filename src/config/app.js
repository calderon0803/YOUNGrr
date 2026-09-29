// The demo backend (data in this browser) is only the default while developing.
// A production build without the variable uses Supabase (and the build refuses
// to run without its configuration, see vite.config.js), never the demo.
export const DATA_SOURCE = import.meta.env.VITE_DATA_SOURCE ?? (import.meta.env.PROD ? 'supabase' : 'local')

/** Public Supabase settings: the anon key is safe in the browser, RLS protects the data. */
export const SUPABASE = {
  url: import.meta.env.VITE_SUPABASE_URL ?? '',
  anonKey: import.meta.env.VITE_SUPABASE_ANON_KEY ?? '',
}

/** Private photos are served through signed URLs valid for this long. */
export const PHOTO_URL_TTL_S = 60 * 60

export const STORAGE_KEYS = {
  // Bumped when the demo dataset changes shape, so old local data is re-seeded.
  db: 'youngrr:db:v20',
  session: 'youngrr:session',
  theme: 'youngrr:theme',
  // Open chat windows, per user (a per-browser convenience).
  chatDock: 'youngrr:chat-dock',
  // Profiles you visited recently, per user, so reloading does not count again.
  visits: 'youngrr:visits',
}

/** The same person does not count again on a profile until this many hours pass. */
export const VISIT_RECOUNT_HOURS = 6

/** Same values as styles/abstracts/_breakpoints.scss. */
export const BREAKPOINTS = { tablet: 768, desktop: 1200 }

/** Chat windows that fit next to the chat panel. */
export const CHAT_MAX_WINDOWS = { tablet: 1, desktop: 3 }
/** How often open chats check for new messages. */
export const CHAT_POLL_INTERVAL_MS = 10_000

/** Browser chrome color per theme (matches $blue-600 / $blue-850). */
export const THEME_COLORS = { light: '#2350a0', dark: '#142a57' }

export const FEED_PAGE_SIZE = 8
export const COMMENT_PREVIEW = 3
/** Name of each person's default album, where every photo is uploaded. */
export const DEFAULT_ALBUM_TITLE = 'Mis fotos'

/** Photos shown in a "ha subido N fotos al álbum" news item. */
export const ALBUM_UPLOAD_PREVIEW = 6

/** Friends' news: activity of the last days, one block per person. */
export const ACTIVITY_WINDOW_DAYS = 30

/** "Quizá conozcas a": people shown in Inicio, and the most in its "Ver todas" list. */
export const SUGGESTIONS_SHOWN = 3
/** Public events in Inicio: shown, and the most in the "Ver todos" list. */
export const PUBLIC_EVENTS_SHOWN = 3
export const PUBLIC_EVENTS_LIMIT = 100
export const SUGGESTIONS_LIMIT = 100

/**
 * Sign up is by invitation only. Each person gets 1 at sign up and 1 more every
 * INVITATION_EVERY_DAYS, up to INVITATIONS_PER_USER (also enforced by the
 * database); an invitation lasts INVITATION_DAYS.
 */
export const INVITATIONS_PER_USER = 5
export const INVITATION_EVERY_DAYS = 7
export const INVITATION_DAYS = 30
export const ACTIVITY_LIMITS = { uploads: 3, newFriends: 5, tagged: 4 }
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
  // Fewer requests (and less of what you type) go to Nominatim.
  minQueryLength: 3,
  limit: 6,
}

/**
 * Automatic check of uploaded images, in the browser (NSFWJS). An image is not
 * uploaded when the pornographic classes (Porn + Hentai) reach `explicit`, or
 * "Sexy" alone reaches `suggestive`. Beach and swimsuit photos usually score
 * "Sexy" well below that.
 */
export const IMAGE_CHECK = { explicit: 0.6, suggestive: 0.9 }

export const IMAGE = {
  maxSide: 1600,
  avatarMaxSide: 600,
  quality: 0.82,
  maxBytes: 20 * 1024 * 1024,
  acceptedTypes: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
}

export const TEXT_LIMITS = {
  // Tuenti's status: one short phrase.
  status: 140,
  commentText: 500,
  wallText: 500,
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
  // YOUNGrr is only for adults (also checked by the database at sign up).
  minAge: 18,
}

export const REPORT_REASONS = [
  'Es spam',
  'Contenido ofensivo',
  'Acoso o intimidación',
  'Información falsa',
  'Otro motivo',
]

// Terms of use and privacy policy. `version` must match yg_terms_version() in
// the database: when the texts change, bump both and everyone accepts the new
// ones on their next sign in.
export const LEGAL = {
  version: '2026-09-29.2',
  updatedOn: '29 de septiembre de 2026 (revisión 2)',
  controller: 'Carlos Calderón',
  contactEmail: 'calderon0803+youngrr@gmail.com',
}
