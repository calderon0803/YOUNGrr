// Profiles and settings with Supabase. Same interface as local/users.local.js.
// Reads go through database functions that apply privacy as the caller.
import { ensureOnline, getSupabase, rpc, toApiError } from '@/services/supabase/client'
import { fromSettings, toPerson, toProfile, toProfileView, toSettings } from '@/services/supabase/mappers'
import { avatarPathFromUrl, avatarUrl, listOwnFiles, removeFiles, signUrls, uploadImage } from '@/services/supabase/storage'
import { ApiError, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { NEARBY_RADII_KM } from '@/config/app'

const PROFILE_VISIBILITIES = ['everyone', 'friends']
const VISIBILITIES = ['everyone', 'friends', 'only_me']
const REQUEST_POLICIES = ['everyone', 'friends_of_friends', 'nobody']
const THEMES = ['system', 'light', 'dark']

const currentUserId = async () => {
  const { data } = await getSupabase().auth.getUser()
  if (!data?.user) throw new ApiError('unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
  return data.user.id
}

const ownProfile = async () => toProfile(await rpc('my_profile', {}, 'No se ha podido cargar tu perfil.'))

export const supabaseUsersService = {
  async getProfile(userId) {
    const view = toProfileView(await rpc('profile_view', { target: userId }, 'No se ha podido cargar el perfil.'))
    // The cover is private: only signed when the profile is visible.
    const urls = await signUrls('covers', [view.profile.coverPath])
    view.profile.coverUrl = urls[view.profile.coverPath] ?? null
    return view
  },

  async registerVisit(userId) {
    await rpc('register_visit', { profile: userId })
  },

  /** First sign in of an account created by hand: name and (optional) town. */
  async completeSetup({ firstName, lastName, location }) {
    validate(
      rules.required(firstName, 'El nombre'),
      rules.max(firstName, LIMITS.name, 'El nombre'),
      rules.required(lastName, 'El apellido'),
      rules.max(lastName, LIMITS.name, 'El apellido'),
      rules.optionalLocation(location),
      rules.max(location?.name, LIMITS.city, 'La ciudad'),
    )
    const row = await rpc(
      'complete_profile_setup',
      { first_name: firstName, last_name: lastName, city: location?.name ?? '', city_lat: location?.lat ?? null, city_lng: location?.lng ?? null },
      'No se ha podido guardar tu perfil.',
    )
    return toProfile(row)
  },

  /** Accounts that did not confirm their age at sign up. Only the confirmation is stored. */
  async confirmAdult(birthDate) {
    validate(rules.adult(birthDate))
    return toProfile(await rpc('confirm_adult', { birth_date: birthDate }, 'No se ha podido comprobar tu edad.'))
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
    // Only the editable fields, through the database (it validates them again).
    const row = await rpc(
      'update_my_profile',
      {
        first_name: update.firstName,
        last_name: update.lastName,
        bio: update.bio,
        birthday: update.birthday || null,
        studies: update.studies,
        work: update.work,
        // Without a town there is no "Cerca de ti", but the profile is still valid.
        city: update.location?.name ?? '',
        city_lat: update.location?.lat ?? null,
        city_lng: update.location?.lng ?? null,
      },
      'No se ha podido guardar el perfil.',
    )
    return toProfile(row)
  },

  /**
   * Avatar (public bucket) or cover (private bucket): uploads the new file,
   * points the profile to it and deletes the one it replaces.
   * @param {'avatarUrl' | 'coverUrl'} field
   */
  async updateImage(field, dataUrl) {
    ensureOnline()
    const id = await currentUserId()
    const isAvatar = field === 'avatarUrl'
    const bucket = isAvatar ? 'avatars' : 'covers'
    const path = await uploadImage(bucket, id, dataUrl, isAvatar ? 'avatar' : 'cover')
    try {
      const data = await rpc(
        'set_profile_image',
        { kind: isAvatar ? 'avatar' : 'cover', value: isAvatar ? avatarUrl(path) : path },
        'No se ha podido guardar la imagen.',
      )
      const previous = isAvatar ? avatarPathFromUrl(data.previous) : data.previous
      await removeFiles(bucket, [previous]).catch(() => {})
      return toProfile(data.profile)
    } catch (error) {
      await removeFiles(bucket, [path]).catch(() => {})
      throw error
    }
  },

  /**
   * Deletes avatars and covers of yours that the profile no longer uses (e.g.
   * if a replacement failed half-way, or public covers from before they
   * became private). Only your own folder.
   */
  async cleanOldProfileImages(profile) {
    const keep = new Set([avatarPathFromUrl(profile.avatarUrl), profile.coverPath].filter(Boolean))
    for (const bucket of ['avatars', 'covers']) {
      const stale = (await listOwnFiles(bucket, profile.id)).filter((path) => !keep.has(path))
      await removeFiles(bucket, stale)
    }
  },

  async getSettings() {
    ensureOnline()
    const id = await currentUserId()
    const { data, error } = await getSupabase().from('user_settings').select('*').eq('user_id', id).single()
    if (error) throw toApiError(error, 'No se han podido cargar tus ajustes.')
    return toSettings(data)
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
    ensureOnline()
    const id = await currentUserId()
    const { data, error } = await getSupabase()
      .from('user_settings')
      .update(fromSettings(next))
      .eq('user_id', id)
      .select('*')
      .single()
    if (error) throw toApiError(error, 'No se han podido guardar los cambios.')
    return toSettings(data)
  },

  async searchPeople(query, { limit = 30 } = {}) {
    if (!query.trim()) return []
    return (await rpc('search_people', { q: query, max_results: limit }, 'No se ha podido buscar.')).map(toPerson)
  },

  async suggestions({ limit = 5 } = {}) {
    return (await rpc('friend_suggestions', { max_results: limit })).map(toPerson)
  },

  async resetDemoData() {
    throw new ApiError('forbidden', 'Los datos de demostración solo existen con el backend local.')
  },
}
