import { defineStore } from 'pinia'
import { reactive } from 'vue'
import { tastesService } from '@/services/tastes.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'

/** Each person's tastes (artists, films and series), by user id. */
export const useTastesStore = defineStore('tastes', () => {
  const toast = useToast()
  const lists = reactive({})

  const load = async (userId) => {
    lists[userId] ??= { status: 'idle', error: null, items: [] }
    const state = lists[userId]
    state.status = state.status === 'success' ? 'success' : 'loading'
    state.error = null
    try {
      state.items = await tastesService.list(userId)
      state.status = 'success'
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
  }

  /** Adds a taste of yours, or changes its stars. Throws so the dialog shows it. */
  const set = async (userId, kind, item, rating = null) => {
    const saved = await tastesService.set(kind, item, rating)
    const state = lists[userId]
    if (state) state.items = [saved, ...state.items.filter((t) => t.id !== saved.id)]
    toast.success(kind === 'artist' ? 'Añadido a tu música.' : 'Valoración guardada.')
    return saved
  }

  const remove = async (userId, tasteId) => {
    try {
      await tastesService.remove(tasteId)
      if (lists[userId]) lists[userId].items = lists[userId].items.filter((t) => t.id !== tasteId)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return { lists, load, set, remove }
})
