import { defineStore } from 'pinia'
import { reactive, ref } from 'vue'
import { TOAST_DURATION_MS } from '@/config/app'

/**
 * @typedef {{ id: number, message: string, tone: 'default' | 'success' | 'error',
 *   action?: { label: string, run: () => void } }} Toast
 */

export const useUiStore = defineStore('ui', () => {
  /** @type {import('vue').Ref<Toast[]>} */
  const toasts = ref([])
  let toastSeq = 0

  const confirmation = reactive({
    open: false,
    title: '',
    message: '',
    confirmLabel: 'Confirmar',
    danger: false,
    resolve: null,
  })

  const dismissToast = (id) => {
    toasts.value = toasts.value.filter((t) => t.id !== id)
  }

  const showToast = (message, { tone = 'default', action, duration = TOAST_DURATION_MS } = {}) => {
    const id = ++toastSeq
    // Keep the stack short: discreet feedback, not a wall of messages.
    toasts.value = [...toasts.value.slice(-2), { id, message, tone, action }]
    setTimeout(() => dismissToast(id), action ? duration + 2500 : duration)
    return id
  }

  /** @returns {Promise<boolean>} */
  const confirm = ({ title, message = '', confirmLabel = 'Confirmar', danger = false }) =>
    new Promise((resolve) => {
      confirmation.resolve?.(false)
      Object.assign(confirmation, { open: true, title, message, confirmLabel, danger, resolve })
    })

  const settleConfirm = (value) => {
    confirmation.resolve?.(value)
    confirmation.open = false
    confirmation.resolve = null
  }

  return { toasts, confirmation, showToast, dismissToast, confirm, settleConfirm }
})
