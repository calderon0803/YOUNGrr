import { onScopeDispose, ref } from 'vue'

export const useOnline = () => {
  const online = ref(typeof navigator === 'undefined' ? true : navigator.onLine)
  const set = () => (online.value = navigator.onLine)
  window.addEventListener('online', set)
  window.addEventListener('offline', set)
  onScopeDispose(() => {
    window.removeEventListener('online', set)
    window.removeEventListener('offline', set)
  })
  return online
}
