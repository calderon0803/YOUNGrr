// Status and friends' activity with Supabase. Same interface as local/posts.local.js.
import { rpc } from '@/services/supabase/client'
import { removePhotos, signPhotoUrls } from '@/services/supabase/storage'
import { blockPhotoPaths, postPhotoPaths, toActivityBlock, toPost } from '@/services/supabase/mappers'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { FEED_PAGE_SIZE, REPORT_REASONS } from '@/config/app'

const withPhotos = async (items) => {
  const urls = await signPhotoUrls(items.flatMap(postPhotoPaths))
  return items.map((p) => toPost(p, urls))
}

/** The database returns one extra block to tell whether there are more. */
const blocksPage = async (items) => {
  const page = items.slice(0, FEED_PAGE_SIZE)
  const urls = await signPhotoUrls(page.flatMap(blockPhotoPaths))
  return { items: page.map((b) => toActivityBlock(b, urls)), hasMore: items.length > FEED_PAGE_SIZE }
}

export const supabasePostsService = {
  async getActivity({ before = null } = {}) {
    return blocksPage(await rpc('friend_activity', { before, page_size: FEED_PAGE_SIZE }, 'No se han podido cargar las novedades.'))
  },

  async getPost(postId) {
    return (await withPhotos([await rpc('get_post', { target: postId }, 'No se ha podido cargar.')]))[0]
  },

  /** The new status replaces the previous one (with its comments and Grr). */
  /** `link`: the Spotify data of a link in the text (the database checks it matches). */
  async setStatus(text, link = null) {
    validate(rules.required(text, 'Tu estado'), rules.max(text, LIMITS.status, 'El estado'))
    return (await withPhotos([await rpc('set_status', { body: text, link }, 'No se ha podido guardar tu estado.')]))[0]
  },

  async deletePost(postId) {
    const removedPath = await rpc('delete_post', { target: postId }, 'No se ha podido eliminar.')
    await removePhotos([removedPath]).catch(() => {})
  },

  async reportPost(postId, reason) {
    validate(REPORT_REASONS.includes(reason) ? null : 'Elige un motivo.')
    await rpc('report_post', { target: postId, reason }, 'No se ha podido enviar el reporte.')
  },
}
