import { defineStore } from 'pinia'
import { reactive, ref } from 'vue'
import { xpService } from '@/services/xp.service'
import { useNotificationsStore } from '@/stores/notifications'
import { toDateInput } from '@/utils/time'

/** Your experience and level, and the levels of the profiles you open. */
export const useXpStore = defineStore('xp', () => {
  const mine = ref(null)
  const levels = reactive({})
  let visitedOn = null

  /** Once a day (on opening YOUNGrr or coming back to it). */
  const recordVisit = async () => {
    const day = toDateInput(new Date())
    if (visitedOn === day) return
    visitedOn = day
    try {
      mine.value = await xpService.recordVisit()
    } catch {
      visitedOn = null
    }
  }

  const loadMine = async () => {
    try {
      mine.value = await xpService.mine()
    } catch {
      // Not essential: the box in Inicio just does not show it.
    }
  }

  const loadLevel = async (userId) => {
    try {
      levels[userId] = await xpService.levelOf(userId)
    } catch {
      levels[userId] = null
    }
  }

  /** Visiting your profile closes the "Has subido al nivel N" counter. */
  const markLevelSeen = async () => {
    try {
      await xpService.markLevelSeen()
      useNotificationsStore().loadSummary()
    } catch {
      // Counters only.
    }
  }

  return { mine, levels, recordVisit, loadMine, loadLevel, markLevelSeen }
})
