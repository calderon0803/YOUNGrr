// Experience and levels. The database awards them (20261117 migration): these
// values must match yg_xp_candidates(), yg_award_instant() and yg_xp_for_level().

/** Days what you publish has to stay to give its experience. */
export const XP_MATURE_DAYS = 7

/** Experience needed to reach level n: 0, 50, 141, 260, 400… */
export const xpForLevel = (n) => (n <= 1 ? 0 : Math.round(50 * Math.pow(n - 1, 1.5)))

export const levelForXp = (xp) => {
  let n = 1
  while (xpForLevel(n + 1) <= xp) n += 1
  return n
}

/** What gives experience, for the "¿Cómo se gana?" explanation. */
export const XP_RULES = [
  { label: 'Subir una foto', points: 2, limit: '10 al día', matures: true },
  { label: 'Comentar algo de otra persona', points: 1, limit: '10 al día', matures: true },
  { label: 'Escribir en el tablón de otra persona', points: 1, limit: '5 al día', matures: true },
  { label: 'Publicar o responder en el Gallinero', points: 1, limit: '10 al día', matures: true },
  { label: 'Valorar una película o serie, o añadir un artista', points: 1, limit: '10 al día', matures: true },
  { label: 'Recibir un Grr de otra persona', points: 1, limit: '20 al día', matures: true },
  { label: 'Una amistad nueva', points: 5, limit: '5 a la semana', matures: true },
  { label: 'Entrar en YOUNGrr', points: 1, limit: '1 al día; +5 a los 7 días seguidos y +20 a los 30', matures: false },
  { label: 'Completar el perfil (foto, presentación y ciudad)', points: 20, limit: 'una vez', matures: false },
  { label: 'Alguien entra con tu invitación', points: 25, limit: 'por cada persona', matures: false },
  { label: 'Conseguir un logro o subir su nivel', points: '10 a 50', limit: 'una vez cada uno', matures: false },
]

/**
 * The look of the level badge: it changes every few levels. `tone` picks the
 * colors (see LevelBadge.vue).
 */
export const levelTone = (level) => {
  if (level >= 50) return 'platinum'
  if (level >= 30) return 'gold'
  if (level >= 20) return 'silver'
  if (level >= 10) return 'bronze'
  return 'base'
}
