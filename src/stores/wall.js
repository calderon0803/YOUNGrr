import { defineStore } from 'pinia'
import { reactive } from 'vue'
import { wallService } from '@/services/wall.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'

/** Profile walls ("tablón") by profile id. */
export const useWallStore = defineStore('wall', () => {
  const toast = useToast()

  const walls = reactive({})

  const loadWall = async (profileId) => {
    walls[profileId] ??= { status: 'idle', error: null, errorCode: null, messages: [], canWrite: false }
    const state = walls[profileId]
    state.status = state.status === 'success' ? 'success' : 'loading'
    state.error = null
    state.errorCode = null
    try {
      Object.assign(state, await wallService.listWall(profileId), { status: 'success' })
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
      state.errorCode = error?.code ?? null
    }
  }

  const addMessage = async (profileId, text) => {
    const message = await wallService.addWallMessage(profileId, text)
    const state = walls[profileId]
    if (state) state.messages = [message, ...state.messages]
    toast.success('Mensaje publicado en el tablón.')
  }

  const deleteMessage = async (profileId, messageId) => {
    try {
      await wallService.deleteWallMessage(messageId)
      const state = walls[profileId]
      if (state) state.messages = state.messages.filter((m) => m.id !== messageId)
      toast.success('Mensaje borrado.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return { walls, loadWall, addMessage, deleteMessage }
})
