// Achievements ("Logros"): names, icons and texts. The codes and thresholds
// must match yg_achievement_defs() in the database (20261106 migration), which
// is what really awards them.
import { Award, Camera, CalendarCheck, Flame, Footprints, Images, MessageSquareHeart, PartyPopper, ScanFace, Sparkles, UserPlus, Users } from 'lucide-vue-next'
import { markRaw } from 'vue'
import GrrIcon from '@/components/common/GrrIcon.vue'

/** Level names for tiered achievements (level 1 to 4). */
export const ACHIEVEMENT_TIERS = ['Bronce', 'Plata', 'Oro', 'Platino']

/** Days to share an achievement with your friends after earning it. */
export const ACHIEVEMENT_SHARE_DAYS = 7

/**
 * @type {Record<string, { name: string, icon: object, thresholds: number[], describe: (n: number) => string }>}
 * `describe` explains what a level (its threshold) takes.
 */
export const ACHIEVEMENTS = {
  fundador: { name: 'Fundador', icon: markRaw(Sparkles), thresholds: [1], describe: () => 'Estar en YOUNGrr antes de la versión 1.0.' },
  primeros_pasos: { name: 'Primeros pasos', icon: markRaw(Footprints), thresholds: [1], describe: () => 'Completar el perfil con tu foto.' },
  estreno: { name: 'Estreno', icon: markRaw(Camera), thresholds: [1], describe: () => 'Subir tu primera foto (la de perfil no cuenta).' },
  anfitrion: { name: 'Anfitrión', icon: markRaw(UserPlus), thresholds: [1, 2, 3, 5], describe: (n) => (n === 1 ? 'Que un amigo entre con tu invitación.' : `Que ${n} amigos entren con tus invitaciones.`) },
  cuadrilla: { name: 'Cuadrilla', icon: markRaw(Users), thresholds: [5, 15, 30, 50], describe: (n) => `Tener ${n} amigos.` },
  organizador: { name: 'Organizador', icon: markRaw(CalendarCheck), thresholds: [1, 5, 15, 30], describe: (n) => (n === 1 ? 'Organizar un plan al que vayan al menos 3 personas.' : `Organizar ${n} planes a los que vayan al menos 3 personas.`) },
  fomo: { name: 'Fomo', icon: markRaw(Flame), thresholds: [3, 10, 25, 50], describe: (n) => `Ir a ${n} planes de otras personas.` },
  planazo: { name: 'Planazo', icon: markRaw(PartyPopper), thresholds: [1], describe: () => 'Organizar un plan con 10 asistentes o más.' },
  fotografo: { name: 'Fotógrafo', icon: markRaw(Images), thresholds: [10, 50, 200, 500], describe: (n) => `Subir ${n} fotos.` },
  album_oro: { name: 'Álbum de oro', icon: markRaw(Award), thresholds: [1], describe: () => 'Tener un álbum con 20 fotos o más.' },
  paparazzi: { name: 'Paparazzi', icon: markRaw(ScanFace), thresholds: [10], describe: () => 'Etiquetar a 10 amigos distintos en tus fotos.' },
  grrrr: { name: 'Grrrr', icon: markRaw(GrrIcon), thresholds: [10, 50, 200, 500], describe: (n) => `Recibir ${n} Grr en tus estados y fotos.` },
  buen_rollo: { name: 'Buen rollo', icon: markRaw(MessageSquareHeart), thresholds: [10], describe: () => 'Escribir en el tablón de 10 amigos distintos.' },
}

/** "Fotógrafo · Oro", or just the name for single-level ones. */
export const achievementLabel = (code, level) => {
  const def = ACHIEVEMENTS[code]
  if (!def) return code
  return def.thresholds.length > 1 ? `${def.name} · ${ACHIEVEMENT_TIERS[level - 1]}` : def.name
}
