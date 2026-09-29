import { TEXT_LIMITS } from '@/config/app'

export const LIMITS = TEXT_LIMITS

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/

/** Each validator returns an error message or null. */
export const rules = {
  required: (value, label) => (String(value ?? '').trim() ? null : `${label} es obligatorio.`),
  max: (value, max, label) =>
    String(value ?? '').length > max ? `${label} no puede superar los ${max} caracteres.` : null,
  email: (value) => (EMAIL_RE.test(String(value ?? '').trim()) ? null : 'Escribe un correo electrónico válido.'),
  password: (value) =>
    String(value ?? '').length >= LIMITS.passwordMin
      ? null
      : `La contraseña debe tener al menos ${LIMITS.passwordMin} caracteres.`,
  date: (value) => (/^\d{4}-\d{2}-\d{2}$/.test(String(value ?? '')) ? null : 'Elige una fecha válida.'),
  /** A town picked from the geocoder: { name, lat, lng }. */
  location: (value) =>
    value?.name?.trim() && Number.isFinite(value.lat) && Number.isFinite(value.lng) && Math.abs(value.lat) <= 90 && Math.abs(value.lng) <= 180
      ? null
      : 'Elige tu ciudad o pueblo de la lista de sugerencias.',
  /** Optional town: empty is fine, a half-filled one is not. */
  optionalLocation: (value) => (value ? rules.location(value) : null),
  /** Birth date (YYYY-MM-DD) of someone aged LIMITS.minAge or over. */
  adult: (value) => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value ?? ''))) return 'Escribe tu fecha de nacimiento.'
    const [y, m, d] = value.split('-').map(Number)
    const today = new Date()
    const limit = new Date(today.getFullYear() - LIMITS.minAge, today.getMonth(), today.getDate())
    if (y < 1900 || new Date(y, m - 1, d) > limit) return `YOUNGrr es solo para mayores de ${LIMITS.minAge} años.`
    return null
  },
  time: (value) => (/^\d{2}:\d{2}$/.test(String(value ?? '')) ? null : 'Elige una hora válida.'),
}

/** Returns the first error of a list of checks, or null. */
export const firstError = (...checks) => checks.find((check) => check) ?? null
