// The title and cover of a Spotify link, from its public oEmbed (no key, no
// account). Only the link goes out (and, as with any request, the IP address).
// Asked once, when publishing the status; the database keeps the result.
import { SPOTIFY } from '@/config/app'
import { spotifyUrl } from '@/utils/spotify'

const COVER = /^https:\/\/(i\.scdn\.co|image-cdn-[a-z]{2}\.spotifycdn\.com|mosaic\.scdn\.co)\/image\/[a-f0-9]{20,80}$/

/**
 * `{ kind, id, title, image }` for a link found with findSpotifyLink(), or null
 * if Spotify does not answer in time (the status is then kept as plain text).
 */
export const fetchSpotifyLink = async (link) => {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), SPOTIFY.timeoutMs)
  try {
    const params = new URLSearchParams({ url: spotifyUrl(link) })
    const response = await fetch(`${SPOTIFY.oembedUrl}?${params}`, {
      signal: controller.signal,
      credentials: 'omit',
      referrerPolicy: 'no-referrer',
      headers: { Accept: 'application/json' },
    })
    if (!response.ok) return null
    const data = await response.json()
    const title = String(data.title ?? '').trim().slice(0, 200)
    if (!title) return null
    return { kind: link.kind, id: link.id, title, image: COVER.test(data.thumbnail_url ?? '') ? data.thumbnail_url : null }
  } catch {
    return null
  } finally {
    clearTimeout(timer)
  }
}
