const MINUTE = 60 * 1000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

const dayMonth = new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'long' })
const dayMonthYear = new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })
const hourMinute = new Intl.DateTimeFormat('es-ES', { hour: '2-digit', minute: '2-digit' })
const weekdayLong = new Intl.DateTimeFormat('es-ES', { weekday: 'long', day: 'numeric', month: 'long' })
const weekdayShort = new Intl.DateTimeFormat('es-ES', { weekday: 'short' })

const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`

const isSameDay = (a, b) => {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

/** "Hace 15 minutos", "Ayer a las 18:30", "12 de marzo"... */
export const relativeTime = (iso, now = Date.now()) => {
  const date = new Date(iso)
  const diff = now - date.getTime()

  if (diff < MINUTE) return 'Ahora mismo'
  if (diff < HOUR) return `Hace ${plural(Math.floor(diff / MINUTE), 'minuto', 'minutos')}`
  if (diff < DAY && isSameDay(date, new Date(now))) {
    return `Hace ${plural(Math.floor(diff / HOUR), 'hora', 'horas')}`
  }

  const yesterday = new Date(now - DAY)
  if (isSameDay(date, yesterday)) return `Ayer a las ${hourMinute.format(date)}`
  if (diff < 7 * DAY) return `Hace ${plural(Math.max(2, Math.floor(diff / DAY)), 'día', 'días')}`

  const sameYear = date.getFullYear() === new Date(now).getFullYear()
  return sameYear ? dayMonth.format(date) : dayMonthYear.format(date)
}

/** Short stamp for conversation lists: "18:32", "ayer", "lun", "12 de marzo". */
export const shortStamp = (iso, now = Date.now()) => {
  const date = new Date(iso)
  const today = new Date(now)
  if (isSameDay(date, today)) return hourMinute.format(date)
  if (isSameDay(date, new Date(now - DAY))) return 'ayer'
  if (now - date.getTime() < 6 * DAY) return weekdayShort.format(date)
  return dayMonth.format(date)
}

export const clockTime = (iso) => hourMinute.format(new Date(iso))

export const fullDate = (iso) => {
  return dayMonthYear.format(new Date(iso))
}

/** Parses a local YYYY-MM-DD + HH:mm pair. */
export const eventDateTime = (date, time) => {
  const [y, m, d] = date.split('-').map(Number)
  const [hh, mm] = (time || '00:00').split(':').map(Number)
  return new Date(y, m - 1, d, hh, mm)
}

/** "sábado, 4 de octubre · 21:30" */
export const formatEventDate = (date, time) => {
  const value = eventDateTime(date, time)
  const label = weekdayLong.format(value)
  return `${label.charAt(0).toUpperCase()}${label.slice(1)} · ${time}`
}

// Three letters for every month; Intl gives "sept" for September.
const SHORT_MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

export const eventDayParts = (date) => {
  const value = eventDateTime(date, '00:00')
  return {
    day: value.getDate(),
    month: SHORT_MONTHS[value.getMonth()],
  }
}

export const isPastEvent = (date, time, now = Date.now()) => {
  return eventDateTime(date, time).getTime() < now - 6 * HOUR
}

/** Local YYYY-MM-DD for a Date. */
export const toDateInput = (value) => {
  const pad = (n) => String(n).padStart(2, '0')
  return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`
}

export const nowIso = () => {
  return new Date().toISOString()
}

/** Whole days from today to a local YYYY-MM-DD date (0 = today, negative = past). */
export const daysUntil = (date, now = new Date()) => {
  const [y, m, d] = date.split('-').map(Number)
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())
  return Math.round((Date.UTC(y, m - 1, d) - today) / 86_400_000)
}

/** "2 oct" for a local YYYY-MM-DD date. */
export const shortDayMonth = (date) => {
  const value = eventDateTime(date, '00:00')
  return `${value.getDate()} ${SHORT_MONTHS[value.getMonth()]}`
}

const weekdayOnly = new Intl.DateTimeFormat('es-ES', { weekday: 'long' })

/** "Hoy", "Ayer", "Lunes" (this week) or "28 de septiembre" for a local YYYY-MM-DD date. */
export const dayLabel = (date, now = new Date()) => {
  const days = -daysUntil(date, now)
  if (days <= 0) return 'Hoy'
  if (days === 1) return 'Ayer'
  const value = eventDateTime(date, '12:00')
  const text = days < 7 ? weekdayOnly.format(value) : dayMonth.format(value)
  return `${text.charAt(0).toUpperCase()}${text.slice(1)}`
}

/** "ago 2022": month and year, for short dates such as "Miembro desde". */
export const monthYear = (iso) => {
  const value = new Date(iso)
  return `${SHORT_MONTHS[value.getMonth()]} ${value.getFullYear()}`
}
