// Finds towns by name with OpenStreetMap (Nominatim).
// Only the text typed goes out (from 3 characters, at most one request per
// second); Nominatim also sees the IP address and the site's origin (it needs
// the Referer to identify the app), never the account or its data.
import { ApiError } from '@/services/errors'
import { GEOCODER } from '@/config/app'

let lastRequestAt = 0

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

/** Keeps us under Nominatim's 1 request/second policy. */
const throttle = async () => {
  const elapsed = Date.now() - lastRequestAt
  if (elapsed < GEOCODER.minIntervalMs) await wait(GEOCODER.minIntervalMs - elapsed)
  lastRequestAt = Date.now()
}

const SETTLEMENT_TYPES = ['city', 'town', 'village', 'hamlet', 'municipality', 'suburb', 'administrative']

const toPlace = (item) => {
  const address = item.address ?? {}
  const name = address.city ?? address.town ?? address.village ?? address.hamlet ?? address.municipality ?? item.name
  const region = address.state ?? address.province ?? address.county ?? ''
  return {
    id: String(item.place_id),
    // Stable id of the place in OpenStreetMap ("osm-R345123"): the key of its group.
    key: item.osm_type && item.osm_id ? `osm-${item.osm_type[0].toUpperCase()}${item.osm_id}` : null,
    name,
    detail: [region, address.country].filter(Boolean).join(', '),
    province: address.province ?? '',
    community: address.state ?? '',
    country: (address.country_code ?? '').toLowerCase(),
  }
}

export const geoService = {
  /**
   * Suggests towns and cities for a query.
   * @returns {Promise<{ id: string, key: string | null, name: string, detail: string, province: string, community: string, country: string }[]>}
   */
  async searchPlaces(query, { signal } = {}) {
    const q = query.trim()
    if (q.length < GEOCODER.minQueryLength) return []
    await throttle()

    const params = new URLSearchParams({
      q,
      format: 'jsonv2',
      addressdetails: '1',
      featureType: 'settlement',
      limit: String(GEOCODER.limit),
      'accept-language': 'es',
    })

    let response
    try {
      response = await fetch(`${GEOCODER.url}?${params}`, {
        signal,
        headers: { Accept: 'application/json' },
        credentials: 'omit',
        referrerPolicy: 'strict-origin-when-cross-origin',
      })
    } catch (error) {
      if (error?.name === 'AbortError') throw error
      throw new ApiError('network', 'No se ha podido buscar la ubicación. Revisa tu conexión.')
    }
    if (!response.ok) throw new ApiError('network', 'El buscador de ubicaciones no responde. Inténtalo en unos segundos.')

    const data = await response.json()
    const seen = new Set()
    return data
      .filter((item) => SETTLEMENT_TYPES.includes(item.addresstype) || item.category === 'place' || item.category === 'boundary')
      .map(toPlace)
      .filter((place) => {
        const key = `${place.name}|${place.detail}`
        if (seen.has(key)) return false
        seen.add(key)
        return true
      })
      // Spanish towns first; the order within each group is Nominatim's relevance.
      .sort((a, b) => Number(b.detail.endsWith('España')) - Number(a.detail.endsWith('España')))
  },
}
