import { storeToRefs } from 'pinia'
import { useUiStore } from '@/stores/ui'

/** Discreet feedback messages. State lives in the ui store. */
export const useToast = () => {
  const ui = useUiStore()
  const { toasts } = storeToRefs(ui)
  return {
    toasts,
    show: ui.showToast,
    success: (message, options) => ui.showToast(message, { ...options, tone: 'success' }),
    error: (message, options) => ui.showToast(message, { ...options, tone: 'error' }),
    dismiss: ui.dismissToast,
  }
}
