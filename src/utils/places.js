import { PLACES } from '@/config/places'
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

