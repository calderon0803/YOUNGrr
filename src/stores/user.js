import { defineStore } from 'pinia'
import { reactive, ref, toRaw } from 'vue'
import { usersService } from '@/services/users.service'
import { geoService } from '@/services/geo.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { useAuthStore } from '@/stores/auth'
import { STORAGE_KEYS, THEME_COLORS } from '@/config/app'
const darkQuery = typeof window !== 'undefined' ? window.matchMedia('(prefers-color-scheme: dark)') : null

export const applyTheme = (preference) => {
  const resolved = preference === 'system' ? (darkQuery?.matches ? 'dark' : 'light') : preference
  document.documentElement.dataset.theme = resolved
  document.querySelectorAll('meta[name="theme-color"]').forEach((meta) => {
    meta.setAttribute('content', THEME_COLORS[resolved])
  })
  try {
    localStorage.setItem(STORAGE_KEYS.theme, preference)
  } catch {
    // Not critical.
  }
}

export const useUserStore = defineStore('user', () => {
  const toast = useToast()
  const auth = useAuthStore()

  /** Profile pages by user id: { status, error, data: ProfileView | null } */
  const profiles = reactive({})
  /** @type {import('vue').Ref<import('@/types/models').UserSettings | null>} */
  const settings = ref(null)

  const entry = (userId) => {
    profiles[userId] ??= { status: 'idle', error: null, data: null }
    return profiles[userId]
  }

  const loadProfile = async (userId, { silent = false } = {}) => {
    const state = entry(userId)
    if (!silent || !state.data) state.status = 'loading'
    state.error = null
    try {
      state.data = await usersService.getProfile(userId)
      state.status = 'success'
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
    return state
  }

  const syncOwnProfile = (profile) => {
    auth.setMe(profile)
    if (profiles[profile.id]?.data) profiles[profile.id].data.profile = profile
  }

  const updateProfile = async (update) => {
    syncOwnProfile(await usersService.updateProfile(update))
    toast.success('Perfil actualizado.')
  }

  /** @param {'avatarUrl' | 'coverUrl'} field */
  const updateImage = async (field, dataUrl) => {
    try {
      syncOwnProfile(await usersService.updateImage(field, dataUrl))
      toast.success(field === 'avatarUrl' ? 'Foto de perfil actualizada.' : 'Portada actualizada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const loadSettings = async () => {
    settings.value = await usersService.getSettings()
    applyTheme(settings.value.appearance.theme)
    return settings.value
  }

  const updateSettings = async (next, message = 'Cambios guardados.') => {
    const previous = settings.value
    settings.value = next
    applyTheme(next.appearance.theme)
    try {
      settings.value = await usersService.updateSettings(next)
      toast.success(message)
    } catch (error) {
      settings.value = previous
      if (previous) applyTheme(previous.appearance.theme)
      toast.error(errorMessage(error))
    }
  }

  /** Editable copy of the settings (structuredClone cannot copy Vue proxies). */
  const draftSettings = () => structuredClone(toRaw(settings.value))

  /** Counts your visit to someone else's profile. Its total stays private to its owner. */
  const registerVisit = async (userId) => {
    try {
      await usersService.registerVisit(userId)
    } catch {
      // The counter is not worth an error message.
    }
  }

  /** Town suggestions for the location picker (OpenStreetMap). */
  const searchPlaces = (query, options) => geoService.searchPlaces(query, options)

  /** Radius of the "Cerca de ti" feed, saved with the rest of the settings. */
  const setNearbyRadius = async (radiusKm) => {
    if (!settings.value || settings.value.nearby?.radiusKm === radiusKm) return
    const next = draftSettings()
    next.nearby = { radiusKm }
    await updateSettings(next, `Mostrando gente a menos de ${radiusKm} km.`)
  }

  return { profiles, settings, loadProfile, updateProfile, updateImage, loadSettings, updateSettings, searchPlaces, setNearbyRadius, registerVisit, draftSettings }
})

// Follow OS changes while the preference is "system".
darkQuery?.addEventListener('change', () => {
  let preference = 'system'
  try {
    preference = localStorage.getItem(STORAGE_KEYS.theme) ?? 'system'
  } catch {
    // Default.
  }
  if (preference === 'system') applyTheme('system')
})
