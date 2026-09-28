// Posts with Supabase. Same interface as local/posts.local.js.
import { currentUserId, rpc } from '@/services/supabase/client'
import { removePhotos, signPhotoUrls, uploadPhoto } from '@/services/supabase/storage'
import { postPhotoPaths, toPost } from '@/services/supabase/mappers'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { FEED_PAGE_SIZE, NEARBY_DEFAULT_RADIUS_KM, NEARBY_RADII_KM, REPORT_REASONS } from '@/config/app'

/** Maps database posts and signs their photo URLs in one call. */
const withPhotos = async (items) => {
  const urls = await signPhotoUrls(items.flatMap(postPhotoPaths))
  return items.map((p) => toPost(p, urls))
}

/** The database returns one extra item to tell whether there are more. */
const page = async (items) => ({
  items: await withPhotos(items.slice(0, FEED_PAGE_SIZE)),
  hasMore: items.length > FEED_PAGE_SIZE,
})

export const supabasePostsService = {
  async getFeed({ before = null } = {}) {
    return page(await rpc('get_feed', { before, page_size: FEED_PAGE_SIZE }, 'No se ha podido cargar el inicio.'))
  },

  async getNearbyFeed({ before = null, radiusKm = NEARBY_DEFAULT_RADIUS_KM } = {}) {
    validate(NEARBY_RADII_KM.includes(radiusKm) ? null : 'Radio no válido.')
    const data = await rpc('get_nearby_feed', { radius_km: radiusKm, before, page_size: FEED_PAGE_SIZE }, 'No se ha podido cargar «Cerca de ti».')
    const { items, hasMore } = await page(data.items)
    const nearby = new Map(data.items.map((p) => [p.id, p.nearby]))
    return {
      items: items.map((post) => {
        const info = nearby.get(post.id)
        return { ...post, nearby: { city: info?.city ?? null, distanceKm: info?.distance_km ?? null } }
      }),
      hasMore,
      needsLocation: data.needs_location,
      originCity: data.origin_city,
    }
  },

  async getUserPosts(userId, { before = null } = {}) {
    return page(await rpc('get_user_posts', { target: userId, before, page_size: FEED_PAGE_SIZE }, 'No se han podido cargar las publicaciones.'))
  },

  async getPost(postId) {
    const [post] = await withPhotos([await rpc('get_post', { target: postId }, 'No se ha podido cargar la publicación.')])
    return post
  },

  /** @param {{ text: string, photo?: { dataUrl: string, width: number, height: number } | null }} input */
  async createPost({ text, photo = null }) {
    validate(text.trim() || photo ? null : 'Escribe algo o añade una fotografía.', rules.max(text, LIMITS.postText, 'La publicación'))
    let path = null
    if (photo) path = await uploadPhoto(await currentUserId(), photo.dataUrl)
    try {
      const created = await rpc(
        'create_post',
        { body: text, photo_path: path, photo_width: photo?.width ?? null, photo_height: photo?.height ?? null },
        'No se ha podido publicar.',
      )
      return (await withPhotos([created]))[0]
    } catch (error) {
      // Do not leave an orphan file if the post could not be created.
      await removePhotos([path]).catch(() => {})
      throw error
    }
  },

  async updatePost(postId, text) {
    validate(rules.max(text, LIMITS.postText, 'La publicación'))
    return (await withPhotos([await rpc('update_post', { target: postId, body: text }, 'No se ha podido guardar.')]))[0]
  },

  async deletePost(postId) {
    const removedPath = await rpc('delete_post', { target: postId }, 'No se ha podido eliminar.')
    await removePhotos([removedPath]).catch(() => {})
  },

  async hidePost(postId) {
    await rpc('hide_post', { target: postId, hidden: true })
  },

  async unhidePost(postId) {
    await rpc('hide_post', { target: postId, hidden: false })
  },

  async reportPost(postId, reason) {
    validate(REPORT_REASONS.includes(reason) ? null : 'Elige un motivo.')
    await rpc('report_post', { target: postId, reason }, 'No se ha podido enviar el reporte.')
  },
}
