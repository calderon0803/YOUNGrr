// Turns a town name into coordinates with OpenStreetMap (Nominatim).
// With a real backend this call should move server-side (caching, rate limit).
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
    name,
    detail: [region, address.country].filter(Boolean).join(', '),
    lat: Number(item.lat),
    lng: Number(item.lon),
  }
}

export const geoService = {
  /**
   * Suggests towns and cities for a query.
   * @returns {Promise<{ id: string, name: string, detail: string, lat: number, lng: number }[]>}
   */
  async searchPlaces(query, { signal } = {}) {
    const q = query.trim()
    if (q.length < 2) return []
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
      response = await fetch(`${GEOCODER.url}?${params}`, { signal, headers: { Accept: 'application/json' } })
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
