import { getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewProfile, personView, visibleCity } from '@/services/local/access'
import { albumView, canSeeEvent, eventView } from '@/services/local/views'
import { matches } from '@/utils/text'

export const searchService = {
  /** Global search, limited to what the user is allowed to see. */
  async search(query) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    if (!query.trim()) return { people: [], events: [], albums: [] }

    const people = db.profiles
      .filter((p) => p.id !== me && matches(`${p.firstName} ${p.lastName} ${visibleCity(db, me, p)}`, query))
      .map((p) => personView(db, me, p.id))
      .sort((a, b) => Number(b.friendship === 'friends') - Number(a.friendship === 'friends') || b.mutualFriends - a.mutualFriends)
      .slice(0, 12)

    const events = db.events
      .filter((e) => canSeeEvent(db, me, e) && matches(`${e.title} ${e.location} ${e.description}`, query))
      .map((e) => eventView(db, me, e))
      .slice(0, 8)

    const albums = db.albums
      .filter((a) => a.kind === 'user' && canViewProfile(db, me, a.ownerId) && matches(`${a.title} ${a.description}`, query))
      .map((a) => albumView(db, a, me))
      .slice(0, 8)

    return { people, events, albums }
  },
}
