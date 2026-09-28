import { defineStore } from 'pinia'
import { computed, reactive } from 'vue'
import { notificationsService } from '@/services/notifications.service'
import { errorMessage } from '@/services/errors'

/**
 * Home-page counters ("3 mensajes privados nuevos"). Each group links to where
 * it is dealt with; visiting that place clears it.
 */
export const useNotificationsStore = defineStore('notifications', () => {
  const summary = reactive({ status: 'idle', error: null, groups: [] })

  const total = computed(() => summary.groups.reduce((sum, g) => sum + g.count, 0))

  const loadSummary = async () => {
    summary.status = summary.status === 'success' ? 'success' : 'loading'
    summary.error = null
    try {
      summary.groups = await notificationsService.getSummary()
      summary.status = 'success'
    } catch (error) {
      summary.status = 'error'
      summary.error = errorMessage(error)
    }
  }

  /**
   * Called by the places that clear counters (a post, a photo, your lists).
   * @param {{ targetId?: string, list?: 'posts' | 'photos' | 'tagged' | 'friends' }} place
   */
  const markSeen = async (place) => {
    try {
      if (await notificationsService.markSeen(place)) await loadSummary()
    } catch {
      // Counters only; not worth bothering the user.
    }
  }

  return { summary, total, loadSummary, markSeen }
})
