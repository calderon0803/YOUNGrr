import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { authService, isLocalBackend } from '@/services/auth.service'
import { usersService } from '@/services/users.service'
import { LEGAL, STORAGE_KEYS } from '@/config/app'

/**
 * What the app leaves in this browser about a session (open chats) goes when
 * signing out, so the next person using it does not see it. The theme stays:
 * it is a preference of the device, not personal data.
 */
const clearBrowserData = () => {
  try {
    Object.keys(localStorage)
      .filter((key) => key.startsWith(STORAGE_KEYS.chatDock) || key.startsWith(STORAGE_KEYS.visits))
      .forEach((key) => localStorage.removeItem(key))
  } catch {
    // Storage blocked: nothing was saved either.
  }
}

export const useAuthStore = defineStore('auth', () => {
  /** @type {import('vue').Ref<import('@/types/models').Profile | null>} */
  const me = ref(null)
  const ready = ref(false)

  const isAuthenticated = computed(() => me.value !== null)
  /**
   * Something to do before using YOUNGrr: profile of an account created by
   * hand, a temporary password, the age of an account from before the check,
   * or terms and privacy policy not accepted in their current version.
   */
  const needsTerms = computed(() => !!me.value && me.value.termsVersion !== LEGAL.version)
  const needsSetup = computed(
    () => !!me.value && (!!me.value.needsSetup || !!me.value.mustChangePassword || me.value.adultConfirmed === false || needsTerms.value),
  )
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

  /** Whatever the account still needs: age, a password of its own, name and town. */
  const completeSetup = async ({ birthDate, password, acceptedTerms, ...profile }) => {
    if (needsTerms.value && acceptedTerms) me.value = await usersService.acceptTerms(LEGAL.version)
    if (me.value.adultConfirmed === false) me.value = await usersService.confirmAdult(birthDate)
    if (me.value.mustChangePassword) {
      await authService.setPassword(password)
      me.value = { ...me.value, mustChangePassword: false }
    }
    if (me.value.needsSetup) me.value = await usersService.completeSetup(profile)
  }

  const requestPasswordReset = (email) => authService.requestPasswordReset(email)
  const hasRecoverySession = () => authService.hasRecoverySession()
  const completePasswordReset = async (next) => {
    me.value = await authService.completePasswordReset(next)
  }
  const changeEmail = (password, next) => authService.changeEmail(password, next)
  const exportData = () => authService.exportData()

  /** Deletes the account and everything in it, then leaves. */
  const deleteAccount = async (password) => {
    await authService.deleteAccount(password)
    clearBrowserData()
    window.location.assign('/login?cuenta=eliminada')
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
    clearBrowserData()
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
    needsTerms,
    isLocalBackend,
    restore,
    login,
    completeSetup,
    requestPasswordReset,
    hasRecoverySession,
    completePasswordReset,
    changeEmail,
    exportData,
    deleteAccount,
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
