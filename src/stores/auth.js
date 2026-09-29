import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { authService, isLocalBackend } from '@/services/auth.service'
import { usersService } from '@/services/users.service'

export const useAuthStore = defineStore('auth', () => {
  /** @type {import('vue').Ref<import('@/types/models').Profile | null>} */
  const me = ref(null)
  const ready = ref(false)

  const isAuthenticated = computed(() => me.value !== null)
  /** Account created by hand that has not completed its profile yet. */
  const needsSetup = computed(() => !!me.value?.needsSetup)
  const meId = computed(() => me.value?.id ?? null)

  const restore = async () => {
    if (ready.value) return
    try {
      me.value = await authService.getSession()
    } catch {
      // Offline or backend unreachable: App shows the offline screen.
      me.value = null
    } finally {
      ready.value = true
    }
  }

  const login = async (email, password) => {
    me.value = await authService.login(email, password)
  }

  /** First sign in: a new password, then name and town. */
  const completeSetup = async ({ password, ...profile }) => {
    await authService.setPassword(password)
    me.value = await usersService.completeSetup(profile)
  }

  /** @returns {Promise<{ needsConfirmation: boolean }>} */
  const register = async (input) => {
    const { profile, needsConfirmation } = await authService.register(input)
    me.value = profile
    return { needsConfirmation }
  }

  const loginDemo = async (userId) => {
    me.value = await authService.loginDemo(userId)
  }

  /** Full reload afterwards, so no state from the previous user survives. */
  const logout = async () => {
    await authService.logout()
    me.value = null
    window.location.assign('/login')
  }

  const setMe = (profile) => {
    me.value = profile
  }

  const listDemoAccounts = () => authService.listDemoAccounts()
  const changePassword = (current, next) => authService.changePassword(current, next)
  const loadEmail = () => authService.getEmail()

  /** Local backend only: wipes this browser's data and restores the demo. */
  const resetDemoData = async () => {
    await usersService.resetDemoData()
    await authService.logout()
    window.location.assign('/login')
  }

  return {
    me,
    meId,
    ready,
    isAuthenticated,
    needsSetup,
    isLocalBackend,
    restore,
    login,
    completeSetup,
    register,
    loginDemo,
    logout,
    setMe,
    listDemoAccounts,
    changePassword,
    loadEmail,
    resetDemoData,
  }
})
