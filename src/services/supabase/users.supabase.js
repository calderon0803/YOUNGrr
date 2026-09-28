// Profiles and settings with Supabase. Same interface as local/users.local.js.
// Reads go through database functions that apply privacy as the caller.
import { ensureOnline, getSupabase, rpc, toApiError } from '@/services/supabase/client'
import { fromSettings, toPerson, toProfile, toProfileView, toSettings } from '@/services/supabase/mappers'
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

/** Data URL (from the image picker) → Blob for Storage uploads. */
const dataUrlToBlob = async (dataUrl) => (await fetch(dataUrl)).blob()

export const supabaseUsersService = {
  async getProfile(userId) {
    return toProfileView(await rpc('profile_view', { target: userId }, 'No se ha podido cargar el perfil.'))
  },

  async registerVisit(userId) {
    return rpc('register_visit', { profile: userId })
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
    ensureOnline()
    const id = await currentUserId()
    const { error } = await getSupabase()
      .from('profiles')
      .update({
        first_name: update.firstName.trim(),
        last_name: update.lastName.trim(),
        // Without a town there is no "Cerca de ti" feed, but the profile is still valid.
        city: update.location?.name.trim() ?? '',
        city_lat: update.location?.lat ?? null,
        city_lng: update.location?.lng ?? null,
        bio: update.bio.trim(),
        birthday: update.birthday || null,
        studies: update.studies.trim(),
        work: update.work.trim(),
      })
      .eq('id', id)
    if (error) throw toApiError(error, 'No se ha podido guardar el perfil.')
    return ownProfile()
  },

  /**
   * Uploads the avatar or cover to the public "avatars" bucket, in the user's
   * own folder, and stores its URL in the profile.
   * @param {'avatarUrl' | 'coverUrl'} field
   */
  async updateImage(field, dataUrl) {
    ensureOnline()
    const supabase = getSupabase()
    const id = await currentUserId()
    const kind = field === 'avatarUrl' ? 'avatar' : 'cover'
    const path = `${id}/${kind}-${Date.now()}.jpg`
    const upload = await supabase.storage
      .from('avatars')
      .upload(path, await dataUrlToBlob(dataUrl), { contentType: 'image/jpeg', upsert: false })
    if (upload.error) throw toApiError(upload.error, 'No se ha podido subir la imagen.')

    const { data } = supabase.storage.from('avatars').getPublicUrl(path)
    const column = field === 'avatarUrl' ? 'avatar_url' : 'cover_url'
    const { error } = await supabase.from('profiles').update({ [column]: data.publicUrl }).eq('id', id)
    if (error) throw toApiError(error, 'No se ha podido guardar la imagen.')
    return ownProfile()
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
