import { defineStore } from 'pinia'
import { reactive } from 'vue'
import { invitationsService } from '@/services/invitations.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'

/** Your invitations: sign up is by invitation only. */
export const useInvitationsStore = defineStore('invitations', () => {
  const toast = useToast()

  /** nextAt: when the next invitation arrives (null once all have been earned). */
  const state = reactive({ status: 'idle', error: null, available: 0, nextAt: null, items: [] })

  const load = async () => {
    state.status = state.status === 'success' ? 'success' : 'loading'
    state.error = null
    try {
      Object.assign(state, await invitationsService.listInvitations(), { status: 'success' })
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
  }

  /** Creates a new single-use invitation link; throws on error. */
  const invite = async () => {
    const invitation = await invitationsService.createInvitation()
    await load()
    return invitation
  }

  const cancel = async (invitationId) => {
    try {
      await invitationsService.cancelInvitation(invitationId)
      await load()
      toast.success('Invitación cancelada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return { state, load, invite, cancel }
})
