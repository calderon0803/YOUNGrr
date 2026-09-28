import { computed, ref } from 'vue'

// Chrome/Edge/Android fire `beforeinstallprompt`; Safari (iOS and macOS) never
// does, so there we explain the manual "Añadir a pantalla de inicio" steps.
const deferred = ref(null)
const installed = ref(false)

if (typeof window !== 'undefined') {
  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault()
    deferred.value = event
  })
  window.addEventListener('appinstalled', () => {
    installed.value = true
    deferred.value = null
  })
}

const isStandalone = () => {
  return (
    window.matchMedia('(display-mode: standalone)').matches ||
    // iOS Safari
    window.navigator.standalone === true
  )
}

const isIos = () => {
  const ua = window.navigator.userAgent
  return /iphone|ipad|ipod/i.test(ua) || (ua.includes('Macintosh') && navigator.maxTouchPoints > 1)
}

export const useInstallPrompt = () => {
  const standalone = computed(() => installed.value || isStandalone())
  const canPrompt = computed(() => !!deferred.value && !standalone.value)
  const needsManualSteps = computed(() => !standalone.value && !deferred.value && isIos())

  const install = async () => {
    if (!deferred.value) return false
    deferred.value.prompt()
    const { outcome } = await deferred.value.userChoice
    deferred.value = null
    return outcome === 'accepted'
  }

  return { standalone, canPrompt, needsManualSteps, install }
}
