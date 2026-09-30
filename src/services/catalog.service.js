// Searches the catalogues of tastes: films and series in TMDB, artists in
// MusicBrainz. Only the text typed goes out (and, as with any request, the IP
// address); never the account. Without a TMDB key, the demo's sample list.
import { ApiError } from '@/services/errors'
import { CATALOGS, DATA_SOURCE } from '@/config/app'
import { SAMPLE_CATALOG } from '@/data/catalog'
import { normalize } from '@/utils/text'

let lastMusicBrainzAt = 0
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

const request = async (url, options = {}) => {
  let response
  try {
    response = await fetch(url, { credentials: 'omit', referrerPolicy: 'strict-origin-when-cross-origin', ...options })
  } catch (error) {
    if (error?.name === 'AbortError') throw error
    throw new ApiError('network', 'No se ha podido buscar. Revisa tu conexión.')
  }
  if (!response.ok) throw new ApiError('network', 'El buscador no responde. Inténtalo en unos segundos.')
  return response.json()
}

const sample = (kind, query) => {
  const q = normalize(query)
  return SAMPLE_CATALOG[kind].filter((item) => normalize(item.title).includes(q)).slice(0, CATALOGS.limit)
}

const tmdb = async (kind, query, signal) => {
  const { url, key } = CATALOGS.tmdb
  const params = new URLSearchParams({ query, language: 'es-ES', include_adult: 'false' })
  // The short "API Key" goes as a parameter; the long read token as a header.
  const headers = { Accept: 'application/json' }
  if (key.length > 40) headers.Authorization = `Bearer ${key}`
  else params.set('api_key', key)
  const data = await request(`${url}/search/${kind === 'series' ? 'tv' : 'movie'}?${params}`, { signal, headers })
  return (data.results ?? []).slice(0, CATALOGS.limit).map((r) => {
    const date = r.release_date ?? r.first_air_date ?? ''
    const year = date ? Number(date.slice(0, 4)) : null
    return {
      source: 'tmdb',
      externalId: String(r.id),
      title: r.title ?? r.name,
      year,
      imagePath: /^\/[A-Za-z0-9_-]{1,60}\.(jpg|png)$/.test(r.poster_path ?? '') ? r.poster_path : null,
      detail: year ? String(year) : '',
    }
  })
}

const musicbrainz = async (query, signal) => {
  const { url, minIntervalMs } = CATALOGS.musicbrainz
  const elapsed = Date.now() - lastMusicBrainzAt
  if (elapsed < minIntervalMs) await wait(minIntervalMs - elapsed)
  lastMusicBrainzAt = Date.now()
  const params = new URLSearchParams({ query, fmt: 'json', limit: String(CATALOGS.limit) })
  const data = await request(`${url}/artist?${params}`, { signal, headers: { Accept: 'application/json' } })
  return (data.artists ?? []).map((a) => ({
    source: 'musicbrainz',
    externalId: a.id,
    title: a.name,
    year: null,
    imagePath: null,
    detail: [a.disambiguation, a.area?.name].filter(Boolean).join(' · '),
  }))
}

export const catalogService = {
  /**
   * @param {'artist' | 'movie' | 'series'} kind
   * @returns {Promise<{ source: string, externalId: string, title: string, year: number | null, imagePath: string | null, detail: string }[]>}
   */
  async search(kind, query, { signal } = {}) {
    const q = query.trim()
    if (q.length < CATALOGS.minQueryLength) return []
    if (kind === 'artist') return DATA_SOURCE === 'local' ? sample(kind, q) : musicbrainz(q, signal)
    return CATALOGS.tmdb.key ? tmdb(kind, q, signal) : sample(kind, q)
  },

  /** Address of a TMDB poster. */
  imageUrl: (path) => (path ? `${CATALOGS.tmdb.imageUrl}${path}` : null),
}
