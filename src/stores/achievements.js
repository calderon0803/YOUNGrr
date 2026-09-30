import { defineStore } from 'pinia'
import { computed, reactive } from 'vue'
import { achievementsService } from '@/services/achievements.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { useAuthStore } from '@/stores/auth'
import { achievementLabel } from '@/config/achievements'

/** Your achievements (with progress) and the ones shown on each profile. */
export const useAchievementsStore = defineStore('achievements', () => {
  const toast = useToast()

  const mine = reactive({ status: 'idle', error: null, items: [] })
  /** Earned achievements by user id: { status, error, items } */
  const byUser = reactive({})

  const earned = computed(() => mine.items.filter((a) => a.level > 0))
  /** Earned lately and not shared yet: they can still be announced. */
  const toShare = computed(() => mine.items.filter((a) => a.canShare))

  const loadMine = async () => {
    mine.status = mine.items.length ? 'success' : 'loading'
    mine.error = null
    try {
      mine.items = await achievementsService.mine()
      mine.status = 'success'
    } catch (error) {
      mine.status = 'error'
      mine.error = errorMessage(error)
    }
  }

  const loadForUser = async (userId) => {
    // Your own profile uses your full list (it also checks for new ones).
    if (userId === useAuthStore().meId) return loadMine()
    byUser[userId] ??= { status: 'idle', error: null, items: [] }
    const state = byUser[userId]
    state.status = state.items.length ? 'success' : 'loading'
    state.error = null
    try {
      state.items = await achievementsService.forUser(userId)
      state.status = 'success'
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
  }

  const share = async (code) => {
    try {
      mine.items = await achievementsService.share(code)
      const a = mine.items.find((x) => x.code === code)
      toast.success(`Has compartido ${achievementLabel(code, a?.level ?? 1)} con tus amigos.`)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return { mine, byUser, earned, toShare, loadMine, loadForUser, share }
})
