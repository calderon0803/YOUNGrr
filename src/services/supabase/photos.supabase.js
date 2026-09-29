// Photos, albums, tags and co-owned photos with Supabase. Same interface as
// local/photos.local.js. Files go to the private "photos" bucket and are shown
// through signed URLs.
import { currentUserId, rpc } from '@/services/supabase/client'
import { removePhotos, signPhotoUrls, uploadPhoto } from '@/services/supabase/storage'
import { toAlbum, toPhoto, toSummary } from '@/services/supabase/mappers'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'

const photosWithUrls = async (items) => {
  const urls = await signPhotoUrls(items.map((p) => p.storage_path))
  return items.map((p) => toPhoto(p, urls))
}

export const albumsWithUrls = async (items) => {
  const urls = await signPhotoUrls(items.map((a) => a.cover_path))
  return items.map((a) => toAlbum(a, urls))
}

const validateAlbum = ({ title, description }) =>
  validate(
    rules.required(title, 'El nombre del álbum'),
    rules.max(title, LIMITS.albumTitle, 'El nombre del álbum'),
    rules.max(description, LIMITS.albumDescription, 'La descripción'),
  )

export const supabasePhotosService = {
  async listAlbums(userId) {
    return albumsWithUrls(await rpc('list_albums', { target: userId }, 'No se han podido cargar los álbumes.'))
  },

  async getAlbum(albumId) {
    const data = await rpc('get_album', { target: albumId }, 'No se ha podido cargar el álbum.')
    const [album] = await albumsWithUrls([data.album])
    return { album, photos: await photosWithUrls(data.photos), canEdit: data.can_edit }
  },

  async createAlbum(input) {
    validateAlbum(input)
    const [album] = await albumsWithUrls([await rpc('create_album', { title: input.title, description: input.description }, 'No se ha podido crear el álbum.')])
    return album
  },

  async updateAlbum(albumId, input) {
    validateAlbum(input)
    const [album] = await albumsWithUrls([await rpc('update_album', { target: albumId, title: input.title, description: input.description }, 'No se ha podido guardar el álbum.')])
    return album
  },

  /** @param {'album' | 'exclusive' | 'all'} mode what goes with the album (see delete_album) */
  async deleteAlbum(albumId, mode = 'album') {
    const paths = await rpc('delete_album', { target: albumId, mode }, 'No se ha podido eliminar el álbum.')
    await removePhotos(paths).catch(() => {})
  },

  /** Adds photos you own to one of your albums; returns the album. */
  async addToAlbum(albumId, photoIds) {
    validate(photoIds.length ? null : 'Elige al menos una fotografía.')
    const [album] = await albumsWithUrls([await rpc('add_to_album', { target: albumId, photo_ids: photoIds }, 'No se han podido añadir las fotos al álbum.')])
    return album
  },

  /** The photo stays in "Mis fotos" and in any other album; returns the album. */
  async removeFromAlbum(albumId, photoId) {
    const [album] = await albumsWithUrls([await rpc('remove_from_album', { target: albumId, photo: photoId }, 'No se ha podido quitar la foto del álbum.')])
    return album
  },

  async setCover(albumId, photoId) {
    const [album] = await albumsWithUrls([await rpc('set_album_cover', { target: albumId, photo: photoId }, 'No se ha podido cambiar la portada.')])
    return album
  },

  /**
   * @param {{ dataUrl: string, width: number, height: number, caption: string }[]} items
   * @param {string[]} coOwnerIds friends invited to co-own every uploaded photo
   */
  async uploadPhotos(items, coOwnerIds = []) {
    validate(items.length ? null : 'Elige al menos una fotografía.')
    items.forEach((item) => validate(rules.max(item.caption, LIMITS.caption, 'El pie de foto')))
    const me = await currentUserId()
    const uploaded = []
    try {
      for (const item of items) {
        uploaded.push({ path: await uploadPhoto(me, item.dataUrl), width: item.width, height: item.height, caption: item.caption })
      }
      const added = await rpc('upload_photos', { items: uploaded, co_owner_ids: coOwnerIds }, 'No se han podido subir las fotografías.')
      return photosWithUrls(added)
    } catch (error) {
      // Do not leave orphan files if the upload could not be completed.
      await removePhotos(uploaded.map((u) => u.path)).catch(() => {})
      throw error
    }
  },

  async updateCaption(photoId, caption) {
    validate(rules.max(caption, LIMITS.caption, 'El pie de foto'))
    const [photo] = await photosWithUrls([await rpc('update_photo_caption', { target: photoId, caption }, 'No se ha podido guardar el pie de foto.')])
    return photo
  },

  /** @returns {Promise<'deleted' | 'left'>} */
  async deletePhoto(photoId) {
    const data = await rpc('delete_photo', { target: photoId }, 'No se ha podido eliminar la fotografía.')
    if (data.storage_path) await removePhotos([data.storage_path]).catch(() => {})
    return data.result
  },

  async inviteCoOwners(photoId, userIds) {
    validate(userIds.length ? null : 'Elige al menos a una persona.')
    const data = await rpc('invite_photo_owners', { target: photoId, people: userIds }, 'No se ha podido enviar la invitación.')
    const [photo] = await photosWithUrls([data.photo])
    return { photo, invited: data.invited }
  },

  async respondOwnerInvite(photoId, accept) {
    const data = await rpc('answer_photo_owner_invite', { target: photoId, accept }, 'No se ha podido responder.')
    if (!data) return null
    return (await photosWithUrls([data]))[0]
  },

  async getPhoto(photoId) {
    return (await photosWithUrls([await rpc('get_photo', { target: photoId }, 'No se ha podido abrir la fotografía.')]))[0]
  },

  async listUserPhotos(userId) {
    return photosWithUrls(await rpc('list_user_photos', { target: userId }, 'No se han podido cargar las fotografías.'))
  },

  async listTaggedPhotos(userId) {
    return photosWithUrls(await rpc('list_tagged_photos', { target: userId }, 'No se han podido cargar las fotografías.'))
  },

  async addTag(photoId, userId, x, y) {
    const t = await rpc('add_photo_tag', { target: photoId, person: userId, x, y }, 'No se ha podido añadir la etiqueta.')
    return {
      id: t.id,
      photoId: t.photo_id,
      userId: t.user_id,
      taggedBy: t.tagged_by,
      x: t.x,
      y: t.y,
      createdAt: t.created_at,
      person: toSummary(t.person),
    }
  },

  async removeTag(tagId) {
    await rpc('remove_photo_tag', { target: tagId }, 'No se ha podido quitar la etiqueta.')
  },
}
