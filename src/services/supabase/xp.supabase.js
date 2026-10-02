// Experience and levels with Supabase. Same interface as local/xp.local.js.
// The database awards everything (see the levels migration).
import { rpc } from '@/services/supabase/client'

const toXp = (json) => ({
  xp: json.xp,
  level: json.level,
  // Experience of the current level and of the next one, for the progress bar.
  levelXp: json.level_xp,
  nextLevelXp: json.next_level_xp,
  // Published in the last days: it becomes experience if it is still there in 7 days.
  pending: json.pending ?? 0,
  streak: json.streak ?? 0,
})

export const supabaseXpService = {
  async mine() {
    return toXp(await rpc('my_xp', {}, 'No se ha podido cargar tu experiencia.'))
  },

  /** Once a day: 1 point, and a bonus at 7 and 30 days in a row. */
  async recordVisit() {
    return toXp(await rpc('record_daily_visit', {}, 'No se ha podido cargar tu experiencia.'))
  },

  /** Someone's level, if you can see their profile (null otherwise). */
  async levelOf(userId) {
    return rpc('user_level', { target: userId }, 'No se ha podido cargar el nivel.')
  },

  async markLevelSeen() {
    await rpc('mark_level_seen', {}, 'No se ha podido actualizar tu nivel.')
  },
}
