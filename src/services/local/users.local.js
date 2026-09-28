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
} from '@/services/local/access'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { matches } from '@/utils/text'
import { NEARBY_RADII_KM } from '@/config/app'
import { toDateInput } from '@/utils/time'

// Friends always see your profile, so it only has two levels.
const PROFILE_VISIBILITIES = ['everyone', 'friends']
const VISIBILITIES = ['everyone', 'friends', 'only_me']
const REQUEST_POLICIES = ['everyone', 'friends_of_friends', 'nobody']
const THEMES = ['system', 'light', 'dark']

// Profiles and settings for the local demo backend. Same interface as users.supabase.js.
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
      : { ...profile, bio: '', birthday: null, studies: '', work: '', coverUrl: null }
    exposed.city = visibleCity(db, me, profile)
    if (userId !== me) {
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
    const day = toDateInput(new Date())
    const already = db.profileVisits.some((v) => v.profileId === userId && v.visitorId === me && v.day === day)
    if (!already) {
      db.profileVisits.push({ profileId: userId, visitorId: me, day })
      profile.visitCount = (profile.visitCount ?? 0) + 1
      await commit()
    }
  },

  async updateProfile(update) {
    validate(
      rules.required(update.firstName, 'El nombre'),
      rules.max(update.firstName, LIMITS.name, 'El nombre'),
      rules.required(update.lastName, 'El apellido'),
      rules.max(update.lastName, LIMITS.name, 'El apellido'),
      update.location ? rules.location(update.location) : null,
      update.location ? rules.max(update.location.name, LIMITS.city, 'La ciudad') : null,
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
      // Without a town there is no "Cerca de ti" feed, but the profile is still valid.
      city: update.location?.name.trim() ?? '',
      cityLat: update.location?.lat ?? null,
      cityLng: update.location?.lng ?? null,
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

  async getSettings() {
    const db = await getDb()
    return structuredClone(db.settings[requireUserId(db)])
  },

  async updateSettings(next) {
    validate(
      PROFILE_VISIBILITIES.includes(next.privacy.profileVisibility) ? null : 'Opción de privacidad no válida.',
      VISIBILITIES.includes(next.privacy.cityVisibility) ? null : 'Opción de privacidad no válida.',
      VISIBILITIES.includes(next.privacy.distanceVisibility) ? null : 'Opción de privacidad no válida.',
      REQUEST_POLICIES.includes(next.privacy.friendRequests) ? null : 'Opción de solicitudes no válida.',
      THEMES.includes(next.appearance.theme) ? null : 'Tema no válido.',
      NEARBY_RADII_KM.includes(next.nearby?.radiusKm) ? null : 'Radio no válido.',
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
      .filter((p) => p.id !== me && matches(`${p.firstName} ${p.lastName} ${visibleCity(db, me, p)}`, query))
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
      .sort((a, b) => b.mutualFriends - a.mutualFriends)
      .slice(0, limit)
  },

  async resetDemoData() {
    await resetDb()
  },
}
