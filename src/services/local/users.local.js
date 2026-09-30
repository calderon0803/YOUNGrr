import { commit, getDb, latency, resetDb } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import {
  canSendRequest,
  canViewProfile,
  canViewPost,
  friendIdsOf,
  friendshipStatus,
  mutualFriends,
  personView,
  profileOf,
  visibleCity,
  isBlockedBetween,
} from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { matches } from '@/utils/text'
import { LEGAL, VISIT_RECOUNT_HOURS } from '@/config/app'

// Friends always see your profile, so it only has two levels.
const PROFILE_VISIBILITIES = ['everyone', 'friends']
const VISIBILITIES = ['everyone', 'friends', 'only_me']
const REQUEST_POLICIES = ['everyone', 'friends_of_friends', 'nobody']
const THEMES = ['system', 'light', 'dark']

// Profiles and settings for the local demo backend. Same interface as users.supabase.js.
/** The status is the latest text-only post (Tuenti's "¿Qué estás haciendo?"). */
const currentStatus = (db, userId) => {
  const latest = db.posts
    .filter((p) => p.authorId === userId && !p.photoId && p.text.trim())
    .reduce((last, p) => (!last || p.createdAt > last.createdAt ? p : last), null)
  return latest ? { postId: latest.id, text: latest.text, createdAt: latest.createdAt } : null
}

export const localUsersService = {
  async getProfile(userId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const profile = profileOf(db, userId)
    const visible = canViewProfile(db, me, userId)

    // A hidden profile only exposes what's needed to send a friend request.
    const exposed = visible
      ? { ...profile }
      : { ...profile, bio: '', birthday: null, studies: '', work: '', coverPath: null }
    exposed.city = visibleCity(db, me, profile)
    if (userId !== me) {
      // Others get the birthday without the year.
      exposed.birthdayDay = visible && profile.birthday ? profile.birthday.slice(5) : null
      exposed.birthday = null
      delete exposed.cityLat
      delete exposed.cityLng
      delete exposed.visitCount
    }

    return {
      profile: exposed,
      friendship: friendshipStatus(db, me, userId),
      friendsCount: friendIdsOf(db, userId).length,
      // Only you see how many visits your profile has (on your home page).
      visits: userId === me ? profile.visitCount ?? 0 : null,
      mutualFriends: mutualFriends(db, me, userId),
      postsCount: visible ? db.posts.filter((p) => p.authorId === userId && canViewPost(db, me, p)).length : 0,
      photosCount: visible ? db.photos.filter((p) => p.ownerId === userId).length : 0,
      canViewProfile: visible,
      canSendRequest: canSendRequest(db, me, userId),
      status: visible ? currentStatus(db, userId) : null,
    }
  },

  /**
   * Counts a visit to someone else's profile, as Tuenti's visit counter did.
   * Your own visits don't count, and each person counts once per day. The total
   * is private: only the owner sees it, on their home page.
   */
  async registerVisit(userId) {
    const db = await getDb()
    const me = requireUserId(db)
    const profile = profileOf(db, userId)
    if (userId === me || !canViewProfile(db, me, userId)) return
    // Once per person and profile every VISIT_RECOUNT_HOURS (the database keeps
    // only a salted hash; the demo keeps the pair, it never leaves the browser).
    const now = Date.now()
    db.visitMarks = Object.fromEntries(Object.entries(db.visitMarks ?? {}).filter(([, until]) => until > now))
    const mark = `${me}:${userId}`
    if (db.visitMarks[mark]) return
    db.visitMarks[mark] = now + VISIT_RECOUNT_HOURS * 3_600_000
    profile.visitCount = (profile.visitCount ?? 0) + 1
    await commit()
  },

  /** First sign in of an account created by hand: name and town, then it is ready. */
  async completeSetup({ firstName, lastName, location }) {
    validate(
      rules.required(firstName, 'El nombre'),
      rules.max(firstName, LIMITS.name, 'El nombre'),
      rules.required(lastName, 'El apellido'),
      rules.max(lastName, LIMITS.name, 'El apellido'),
      rules.optionalLocation(location),
      rules.max(location?.name, LIMITS.city, 'La ciudad'),
    )
    await latency()
    const db = await getDb()
    const profile = profileOf(db, requireUserId(db))
    Object.assign(profile, {
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      city: location?.name.trim() ?? '',
      // Only the name of the town is kept, never its coordinates.
      cityLat: null,
      cityLng: null,
      needsSetup: false,
    })
    await commit()
    return { ...profile }
  },

  /** Accounts that did not confirm their age at sign up. Only the confirmation is stored. */
  async confirmAdult(birthDate) {
    validate(rules.adult(birthDate))
    await latency()
    const db = await getDb()
    const profile = profileOf(db, requireUserId(db))
    profile.adultConfirmed = true
    await commit()
    return { ...profile }
  },

  async acceptTerms(version) {
    await latency()
    const db = await getDb()
    const profile = profileOf(db, requireUserId(db))
    ensure(version === LEGAL.version, 'conflict', 'Las condiciones han cambiado. Recarga la página para ver las nuevas.')
    profile.termsVersion = version
    await commit()
    return { ...profile }
  },

  async updateProfile(update) {
    validate(
      rules.required(update.firstName, 'El nombre'),
      rules.max(update.firstName, LIMITS.name, 'El nombre'),
      rules.required(update.lastName, 'El apellido'),
      rules.max(update.lastName, LIMITS.name, 'El apellido'),
      rules.optionalLocation(update.location),
      rules.max(update.location?.name, LIMITS.city, 'La ciudad'),
      rules.max(update.bio, LIMITS.bio, 'La biografía'),
      rules.max(update.studies, LIMITS.about, 'Estudios'),
      rules.max(update.work, LIMITS.about, 'Trabajo'),
      update.birthday ? rules.date(update.birthday) : null,
    )
    await latency()
    const db = await getDb()
    const profile = profileOf(db, requireUserId(db))
    Object.assign(profile, {
      firstName: update.firstName.trim(),
      lastName: update.lastName.trim(),
      // The town is optional (it only suggests the groups of your area).
      city: update.location?.name.trim() ?? '',
      cityLat: null,
      cityLng: null,
      bio: update.bio.trim(),
      birthday: update.birthday || null,
      studies: update.studies.trim(),
      work: update.work.trim(),
    })
    await commit()
    return { ...profile }
  },

  /** @param {'avatarUrl' | 'coverUrl'} field */
  async updateImage(field, dataUrl) {
    await latency(200, 450)
    const db = await getDb()
    const profile = profileOf(db, requireUserId(db))
    profile[field] = dataUrl
    await commit()
    return { ...profile }
  },

  /** Demo backend: images live in the data itself, nothing to clean up. */
  async cleanOldProfileImages() {},

  async getSettings() {
    const db = await getDb()
    return structuredClone(db.settings[requireUserId(db)])
  },

  async updateSettings(next) {
    validate(
      PROFILE_VISIBILITIES.includes(next.privacy.profileVisibility) ? null : 'Opción de privacidad no válida.',
      VISIBILITIES.includes(next.privacy.cityVisibility) ? null : 'Opción de privacidad no válida.',
      REQUEST_POLICIES.includes(next.privacy.friendRequests) ? null : 'Opción de solicitudes no válida.',
      THEMES.includes(next.appearance.theme) ? null : 'Tema no válido.',
    )
    await latency(80, 160)
    const db = await getDb()
    const me = requireUserId(db)
    db.settings[me] = structuredClone(next)
    await commit()
    return structuredClone(db.settings[me])
  },

  async searchPeople(query, { limit = 30 } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    return db.profiles
      .filter((p) => p.id !== me && !isBlockedBetween(db, me, p.id) && matches(`${p.firstName} ${p.lastName} ${visibleCity(db, me, p)}`, query))
      .slice(0, limit)
      .map((p) => personView(db, me, p.id))
      .sort((a, b) => b.mutualFriends - a.mutualFriends)
  },

  /** People you may know: friends of friends you can send a request to. */
  async suggestions({ limit = 5 } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    return db.profiles
      .filter((p) => p.id !== me && friendshipStatus(db, me, p.id) === 'none' && mutualFriends(db, me, p.id) > 0)
      .map((p) => personView(db, me, p.id))
      .filter((p) => p.canSendRequest)
      // Most friends in common first, then by name.
      .sort((a, b) => b.mutualFriends - a.mutualFriends || a.firstName.localeCompare(b.firstName, 'es') || a.lastName.localeCompare(b.lastName, 'es'))
      .slice(0, limit)
  },

  async resetDemoData() {
    await resetDb()
  },
}
