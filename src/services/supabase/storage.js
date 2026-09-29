// Files in Supabase Storage, always at <owner_id>/<file>:
// - "photos" (private): album photos and event images, shown through
//   short-lived signed URLs to whoever can see them.
// - "covers" (private): profile covers, following profile privacy.
// - "avatars" (public): profile pictures, basic identification.
// The buckets only accept JPEG images of a bounded size (the app re-encodes
// every picture in the browser before uploading it).
import { getSupabase, toApiError } from '@/services/supabase/client'
import { uid } from '@/utils/ids'
import { PHOTO_URL_TTL_S } from '@/config/app'

export const BUCKETS = ['photos', 'covers', 'avatars']
const LIST_PAGE = 100

const dataUrlToBlob = async (dataUrl) => (await fetch(dataUrl)).blob()

/** Uploads a picked image (data URL) to your folder and returns its path. */
export const uploadImage = async (bucket, userId, dataUrl, prefix = 'ph') => {
  const path = `${userId}/${uid(prefix)}.jpg`
  const { error } = await getSupabase()
    .storage.from(bucket)
    .upload(path, await dataUrlToBlob(dataUrl), { contentType: 'image/jpeg', upsert: false })
  if (error) throw toApiError(error, 'No se ha podido subir la imagen.')
  return path
}

export const uploadPhoto = (userId, dataUrl) => uploadImage('photos', userId, dataUrl)

export const removeFiles = async (bucket, paths) => {
  const list = paths.filter(Boolean)
  if (list.length) await getSupabase().storage.from(bucket).remove(list)
}

export const removePhotos = (paths) => removeFiles('photos', paths)

/** Signed URLs for many paths at once: { [path]: url }. */
export const signUrls = async (bucket, paths) => {
  const unique = [...new Set(paths.filter(Boolean))]
  if (!unique.length) return {}
  const { data, error } = await getSupabase().storage.from(bucket).createSignedUrls(unique, PHOTO_URL_TTL_S)
  if (error) throw toApiError(error, 'No se han podido cargar las fotografías.')
  return Object.fromEntries(data.filter((item) => item.signedUrl).map((item) => [item.path, item.signedUrl]))
}

export const signPhotoUrls = (paths) => signUrls('photos', paths)

/** Public URL of an avatar path, and the path back from such a URL. */
export const avatarUrl = (path) => getSupabase().storage.from('avatars').getPublicUrl(path).data.publicUrl
export const avatarPathFromUrl = (url) => {
  const marker = '/storage/v1/object/public/avatars/'
  const at = url?.indexOf(marker) ?? -1
  return at === -1 ? null : decodeURIComponent(url.slice(at + marker.length).split('?')[0])
}

/** Paths in your own folder of a bucket (first LIST_PAGE files). */
export const listOwnFiles = async (bucket, userId) => {
  const { data, error } = await getSupabase().storage.from(bucket).list(userId, { limit: LIST_PAGE })
  if (error) throw toApiError(error, 'No se han podido revisar tus archivos.')
  return (data ?? []).filter((f) => f.id).map((f) => `${userId}/${f.name}`)
}

/** Deletes every file in your own folder of every bucket (to delete the account). */
export const removeAllOwnFiles = async (userId) => {
  const storage = getSupabase().storage
  for (const bucket of BUCKETS) {
    // Deleting shifts the listing, so always read the first page until it is empty.
    for (;;) {
      const { data, error } = await storage.from(bucket).list(userId, { limit: LIST_PAGE })
      if (error) throw toApiError(error, 'No se han podido borrar tus archivos.')
      const names = (data ?? []).filter((f) => f.id).map((f) => `${userId}/${f.name}`)
      if (!names.length) break
      const removed = await storage.from(bucket).remove(names)
      // Nothing removed without an error would loop forever: stop instead.
      if (removed.error || !removed.data?.length) throw toApiError(removed.error, 'No se han podido borrar tus archivos.')
    }
  }
}
