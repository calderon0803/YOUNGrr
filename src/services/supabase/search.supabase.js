// Global search with Supabase. Same interface as local/search.local.js.
import { rpc } from '@/services/supabase/client'
import { toPerson } from '@/services/supabase/mappers'
import { eventsWithImages } from '@/services/supabase/events.supabase'
import { albumsWithUrls } from '@/services/supabase/photos.supabase'

export const supabaseSearchService = {
  /** Global search, limited to what the user is allowed to see. */
  async search(query) {
    if (!query.trim()) return { people: [], events: [], albums: [] }
    const data = await rpc('global_search', { q: query }, 'No se ha podido buscar.')
    const [events, albums] = await Promise.all([eventsWithImages(data.events), albumsWithUrls(data.albums)])
    return { people: data.people.map(toPerson), events, albums }
  },
}
