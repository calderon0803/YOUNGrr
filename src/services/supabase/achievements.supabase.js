// Achievements with Supabase. Same interface as local/achievements.local.js.
// The database awards them (my_achievements checks them first).
import { rpc } from '@/services/supabase/client'

const toMine = (json) => ({
  code: json.code,
  thresholds: json.thresholds,
  level: json.level,
  progress: json.progress,
  earnedAt: json.earned_at ?? null,
  sharedAt: json.shared_at ?? null,
  shareUntil: json.share_until ?? null,
  canShare: !!json.can_share,
})

export const supabaseAchievementsService = {
  async mine() {
    return (await rpc('my_achievements', {}, 'No se han podido cargar tus logros.')).map(toMine)
  },

  async forUser(userId) {
    const data = await rpc('user_achievements', { target: userId }, 'No se han podido cargar los logros.')
    return data.map((a) => ({ code: a.code, level: a.level, earnedAt: a.earned_at }))
  },

  async share(code) {
    return (await rpc('share_achievement', { what: code }, 'No se ha podido compartir el logro.')).map(toMine)
  },
}
