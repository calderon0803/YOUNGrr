import { useUiStore } from '@/stores/ui'

/** App-wide confirmation dialog, rendered once by ConfirmHost. */
export const useConfirm = () => {
  const ui = useUiStore()
  return { state: ui.confirmation, confirm: ui.confirm, settle: ui.settleConfirm }
}
