// Tastes with Supabase. Same interface as local/tastes.local.js.
import { rpc } from '@/services/supabase/client'
import { validate } from '@/services/errors'

export const toTaste = (json) => ({
  id: json.id,
  kind: json.kind,
  source: json.source,
  externalId: json.external_id,
  title: json.title,
  year: json.year ?? null,
  imagePath: json.image_path ?? null,
  // Films and series: 0.5 to 5 stars; artists: null.
  rating: json.rating === null || json.rating === undefined ? null : Number(json.rating),
  updatedAt: json.updated_at,
})

const validRating = (kind, rating) => kind === 'artist' || (rating >= 0.5 && rating <= 5 && Number.isInteger(rating * 2))

export const supabaseTastesService = {
  async list(userId) {
    return (await rpc('list_tastes', { target: userId }, 'No se han podido cargar los gustos.')).map(toTaste)
  },

  /** Adds a taste, or changes its stars. */
  async set(kind, item, rating = null) {
    validate(validRating(kind, rating) ? null : 'Elige de media a cinco estrellas.')
    return toTaste(
      await rpc(
        'set_taste',
        {
          taste_kind: kind,
          catalog: item.source,
          catalog_id: item.externalId,
          taste_title: item.title,
          taste_year: item.year,
          poster: item.imagePath,
          stars: kind === 'artist' ? null : rating,
        },
        'No se ha podido guardar.',
      ),
    )
  },

  async remove(tasteId) {
    await rpc('remove_taste', { target: tasteId }, 'No se ha podido quitar.')
  },
}
