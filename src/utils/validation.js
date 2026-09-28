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
  time: (value) => (/^\d{2}:\d{2}$/.test(String(value ?? '')) ? null : 'Elige una hora válida.'),
}

/** Returns the first error of a list of checks, or null. */
export const firstError = (...checks) => checks.find((check) => check) ?? null
