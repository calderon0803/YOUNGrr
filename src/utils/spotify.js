import { SPOTIFY } from '@/config/app'

// Links to open.spotify.com in a status: a song, album, playlist, artist,
// podcast or episode. Pasted links usually carry a language path (/intl-es/)
// and a "?si=" code that tells Spotify who shared it: both are dropped.

const LINK = /https?:\/\/open\.spotify\.com\/(?:intl-[a-z]{2}(?:-[a-z]{2})?\/)?(track|album|playlist|artist|show|episode)\/([A-Za-z0-9]{22})(?:\?[^\s]*)?/i

/** The clean link of the item, e.g. https://open.spotify.com/track/<id>. */
export const spotifyUrl = ({ kind, id }) => `https://open.spotify.com/${kind}/${id}`

/** The first Spotify link in a text: `{ kind, id, url }`, or null. */
export const findSpotifyLink = (text) => {
  const match = LINK.exec(text ?? '')
  if (!match) return null
  const kind = match[1].toLowerCase()
  return SPOTIFY.kinds[kind] ? { kind, id: match[2], url: spotifyUrl({ kind, id: match[2] }), raw: match[0] } : null
}

/** The text with the Spotify link cleaned (no language path or "?si=" code). */
export const cleanSpotifyText = (text) => {
  const link = findSpotifyLink(text)
  return link ? text.replace(link.raw, link.url) : text
}

/** The text without the link, when the card already shows it. */
export const withoutSpotifyLink = (text, link) => {
  if (!link) return text
  return text.replace(spotifyUrl(link), '').replace(/\s{2,}/g, ' ').trim()
}
