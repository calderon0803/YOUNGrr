const EARTH_RADIUS_KM = 6371

const toRad = (deg) => (deg * Math.PI) / 180

/** Great-circle distance (haversine) between two { lat, lng } points, in km. */
export const distanceKm = (a, b) => {
  const dLat = toRad(b.lat - a.lat)
  const dLng = toRad(b.lng - a.lng)
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h))
}

export const hasLocation = (profile) => typeof profile?.cityLat === 'number' && typeof profile?.cityLng === 'number'

/** Only town-level distances, never exact positions: "en tu zona", "a 12 km". */
export const formatDistance = (km) => (km < 2 ? 'en tu zona' : `a ${Math.round(km)} km`)
