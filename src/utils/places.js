import { PLACES } from '@/config/places'
import { FLAG_KEYS } from '@/config/flags'
import { normalize } from '@/utils/text'

const names = (place) => [place.name, ...place.aliases].map(normalize)

/**
 * The group a town belongs to, from what the geocoder says: its province, or
 * its community when it has a single province. null when it is not in Spain
 * or cannot be told.
 * @param {{ province?: string, community?: string, country?: string }} place
 */
export const placeParentKey = (place) => {
  if (place?.country && place.country !== 'es') return null
  const province = normalize(place?.province ?? '')
  const community = normalize(place?.community ?? '')
  for (const c of PLACES) {
    for (const p of c.provinces ?? []) if (province && names(p).includes(province)) return p.key
  }
  const found = PLACES.find((c) => (community && names(c).includes(community)) || (province && names(c).includes(province)))
  if (!found) return null
  // A community with provinces: the province is not known, so the community.
  return found.key
}

const communityOf = (key) => PLACES.find((c) => c.key === key || (c.provinces ?? []).some((p) => p.key === key))?.key ?? null

/**
 * The flag of a place group: its own, or its community's when it has none
 * official; towns show the one of the place above them.
 * @param {{ placeKey?: string | null, placeLevel?: string | null, parent?: { placeKey?: string | null } | null }} group
 */
export const placeFlagUrl = (group) => {
  const key = group?.placeLevel === 'municipality' ? group.parent?.placeKey : group?.placeKey
  if (!key) return null
  const flag = FLAG_KEYS.has(key) ? key : communityOf(key)
  return flag && FLAG_KEYS.has(flag) ? `/flags/${flag}.png` : null
}
