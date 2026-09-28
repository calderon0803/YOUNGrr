// Photos live in the private "photos" bucket at <owner_id>/<file>. Storage
// policies only let people who can see the owner's profile read them, so the
// app shows them through short-lived signed URLs.
import { getSupabase, toApiError } from '@/services/supabase/client'
import { uid } from '@/utils/ids'
import { PHOTO_URL_TTL_S } from '@/config/app'

const BUCKET = 'photos'

const dataUrlToBlob = async (dataUrl) => (await fetch(dataUrl)).blob()

/** Uploads a picked image (data URL) and returns its Storage path. */
export const uploadPhoto = async (userId, dataUrl) => {
  const path = `${userId}/${uid('ph')}.jpg`
  const { error } = await getSupabase()
    .storage.from(BUCKET)
    .upload(path, await dataUrlToBlob(dataUrl), { contentType: 'image/jpeg', upsert: false })
  if (error) throw toApiError(error, 'No se ha podido subir la fotografía.')
  return path
}

export const removePhotos = async (paths) => {
  const list = paths.filter(Boolean)
  if (list.length) await getSupabase().storage.from(BUCKET).remove(list)
}

/** Signed URLs for many paths at once: { [path]: url }. */
export const signPhotoUrls = async (paths) => {
  const unique = [...new Set(paths.filter(Boolean))]
  if (!unique.length) return {}
  const { data, error } = await getSupabase().storage.from(BUCKET).createSignedUrls(unique, PHOTO_URL_TTL_S)
  if (error) throw toApiError(error, 'No se han podido cargar las fotografías.')
  return Object.fromEntries(data.filter((item) => item.signedUrl).map((item) => [item.path, item.signedUrl]))
}
