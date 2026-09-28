export const fullName = (person) => (person ? `${person.firstName} ${person.lastName}`.trim() : '')

export const initials = (person) => {
  if (!person) return ''
  return `${person.firstName.charAt(0)}${person.lastName.charAt(0)}`.toUpperCase()
}

export const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`

/** Lowercase and strip accents so "Lucía" matches "lucia". */
export const normalize = (value) => {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
}

export const matches = (haystack, query) => {
  const q = normalize(query)
  return q.length > 0 && normalize(haystack).includes(q)
}
