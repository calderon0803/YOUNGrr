import { defineStore } from 'pinia'
import { computed, reactive, ref } from 'vue'
import { photosService } from '@/services/photos.service'
import { interactionsService } from '@/services/interactions.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { useNotificationsStore } from '@/stores/notifications'
import { GRR_TOAST_DURATION_MS } from '@/config/app'

/** @typedef {import('@/types/models').PhotoView} PhotoView */

const idleList = () => ({ status: 'idle', error: null, errorCode: null, errorOwnerId: null, ids: [] })

export const usePhotosStore = defineStore('photos', () => {
  const toast = useToast()

  /** Normalized photos shared by albums, profile grids and the viewer. */
  const photos = reactive(/** @type {Record<string, PhotoView>} */ ({}))
  const albums = reactive({})
  const albumsByUser = reactive({})
  const albumDetail = reactive({})
  const lists = reactive({})
  const grrPending = ref(new Set())

  // Viewer: an ordered list of photo ids and the current index.
  const viewer = reactive({ open: false, ids: [], index: 0, detailStatus: 'idle', detailError: null, detailErrorCode: null, detailOwnerId: null })
  const currentPhoto = computed(() => (viewer.open ? photos[viewer.ids[viewer.index]] ?? null : null))

  const keep = (items) => {
    for (const photo of items) photos[photo.id] = { ...photos[photo.id], ...photo }
    return items.map((p) => p.id)
  }

  const track = async (state, fn) => {
    state.status = state.status === 'success' ? 'success' : 'loading'
    state.error = null
    state.errorCode = null
    state.errorOwnerId = null
    try {
      await fn()
      state.status = 'success'
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
      // Lets the UI tell "private" apart from "failed to load".
      state.errorCode = error?.code ?? null
      // Whose content it was, to send the viewer to their profile.
      state.errorOwnerId = error?.details?.ownerId ?? null
    }
  }

  const loadAlbums = (userId) => {
    albumsByUser[userId] ??= idleList()
    const state = albumsByUser[userId]
    return track(state, async () => {
      const items = await photosService.listAlbums(userId)
      for (const album of items) albums[album.id] = album
      state.ids = items.map((a) => a.id)
    })
  }

  const loadAlbum = (albumId) => {
    albumDetail[albumId] ??= { ...idleList(), canEdit: false }
    const state = albumDetail[albumId]
    return track(state, async () => {
      const result = await photosService.getAlbum(albumId)
      albums[albumId] = result.album
      state.ids = keep(result.photos)
      state.canEdit = result.canEdit
    })
  }

  /** @param {'user' | 'tagged' | 'friends'} kind */
  const loadList = (key, fetcher) => {
    lists[key] ??= idleList()
    const state = lists[key]
    return track(state, async () => {
      state.ids = keep(await fetcher())
    })
  }

  const loadUserPhotos = (userId) => loadList(`user:${userId}`, () => photosService.listUserPhotos(userId))
  const loadTaggedPhotos = (userId) => loadList(`tagged:${userId}`, () => photosService.listTaggedPhotos(userId))

  const refreshAlbum = (album) => {
    albums[album.id] = album
    const list = albumsByUser[album.ownerId]
    if (list && !list.ids.includes(album.id)) list.ids = [album.id, ...list.ids]
  }

  const createAlbum = async (input) => {
    const album = await photosService.createAlbum(input)
    refreshAlbum(album)
    toast.success('Álbum creado.')
    return album
  }

  const updateAlbum = async (albumId, input) => {
    refreshAlbum(await photosService.updateAlbum(albumId, input))
    toast.success('Álbum actualizado.')
  }

  /** @param {'album' | 'exclusive' | 'all'} mode only the album, also the photos only in it, or also all its photos */
  const deleteAlbum = async (albumId, mode = 'album') => {
    const ownerId = albums[albumId]?.ownerId
    await photosService.deleteAlbum(albumId, mode)
    if (ownerId && albumsByUser[ownerId]) albumsByUser[ownerId].ids = albumsByUser[ownerId].ids.filter((id) => id !== albumId)
    delete albums[albumId]
    delete albumDetail[albumId]
    // Some photos went too: the lists that had them load again when shown.
    if (mode !== 'album') forgetOwnerLists(ownerId)
    toast.success(mode === 'album' ? 'Álbum eliminado. Sus fotos siguen en Mis fotos.' : 'Álbum y fotos eliminados.')
  }

  /** Drops the cached albums and photo lists of a person, to load them again. */
  const forgetOwnerLists = (ownerId) => {
    for (const key of Object.keys(lists)) if (key.endsWith(`:${ownerId}`)) delete lists[key]
    for (const [id, album] of Object.entries(albums)) if (album.ownerId === ownerId) delete albumDetail[id]
    delete albumsByUser[ownerId]
  }

  /**
   * Every photo goes to "Mis fotos".
   * @param {string[]} coOwnerIds friends invited to co-own the uploaded photos
   */
  const uploadPhotos = async (items, coOwnerIds = []) => {
    const added = await photosService.uploadPhotos(items, coOwnerIds)
    const ids = keep(added)
    const ownerId = added[0]?.ownerId
    const defaultAlbum = Object.values(albums).find((a) => a.ownerId === ownerId && a.kind === 'wall')
    if (defaultAlbum) {
      if (albumDetail[defaultAlbum.id]) albumDetail[defaultAlbum.id].ids = [...albumDetail[defaultAlbum.id].ids, ...ids]
      defaultAlbum.photoCount += ids.length
      defaultAlbum.coverUrl ??= added[0]?.url ?? null
    }
    const own = lists[`user:${ownerId}`]
    if (own) own.ids = [...ids, ...own.ids]
    const uploaded = ids.length === 1 ? 'Fotografía subida.' : `${ids.length} fotografías subidas.`
    toast.success(coOwnerIds.length ? `${uploaded} Invitación para compartirla enviada.` : uploaded)
  }

  /** Adds photos already uploaded to one of your albums. */
  const addToAlbum = async (albumId, photoIds) => {
    refreshAlbum(await photosService.addToAlbum(albumId, photoIds))
    const detail = albumDetail[albumId]
    if (detail) detail.ids = [...detail.ids, ...photoIds.filter((id) => !detail.ids.includes(id))]
    toast.success(photoIds.length === 1 ? `Foto añadida a ${albums[albumId].title}.` : `${photoIds.length} fotos añadidas a ${albums[albumId].title}.`)
  }

  const removeFromAlbum = async (albumId, photoId) => {
    try {
      refreshAlbum(await photosService.removeFromAlbum(albumId, photoId))
      const detail = albumDetail[albumId]
      if (detail) detail.ids = detail.ids.filter((id) => id !== photoId)
      if (viewer.open && viewer.ids.includes(photoId)) {
        viewer.ids = viewer.ids.filter((id) => id !== photoId)
        if (!viewer.ids.length) closeViewer()
        else viewer.index = Math.min(viewer.index, viewer.ids.length - 1)
      }
      toast.success('Foto quitada del álbum. Sigue en Mis fotos.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const setCover = async (albumId, photoId) => {
    try {
      albums[albumId] = await photosService.setCover(albumId, photoId)
      toast.success('Portada del álbum cambiada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const updateCaption = async (photoId, caption) => {
    const updated = await photosService.updateCaption(photoId, caption)
    photos[photoId] = { ...photos[photoId], caption: updated.caption }
    toast.success('Pie de foto guardado.')
  }

  const deletePhoto = async (photoId) => {
    const photo = photos[photoId]
    try {
      const result = await photosService.deletePhoto(photoId)
      // Every album that showed it has one photo less.
      for (const [id, detail] of Object.entries(albumDetail)) {
        if (detail.ids.includes(photoId) && albums[id]) albums[id].photoCount -= 1
      }
      if (photo && !albumDetail[photo.albumId] && albums[photo.albumId]) albums[photo.albumId].photoCount -= 1
      for (const state of [...Object.values(albumDetail), ...Object.values(lists)]) {
        state.ids = state.ids.filter((id) => id !== photoId)
      }
      if (viewer.open) {
        viewer.ids = viewer.ids.filter((id) => id !== photoId)
        if (!viewer.ids.length) closeViewer()
        else viewer.index = Math.min(viewer.index, viewer.ids.length - 1)
      }
      delete photos[photoId]
      toast.success(result === 'left' ? 'La foto ya no está en tu perfil. Sigue en el de los otros dueños.' : 'Fotografía eliminada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  // ---- Viewer -------------------------------------------------------------

  const loadDetail = async (photoId) => {
    viewer.detailStatus = 'loading'
    viewer.detailError = null
    viewer.detailErrorCode = null
    viewer.detailOwnerId = null
    try {
      const detail = await photosService.getPhoto(photoId)
      photos[photoId] = { ...photos[photoId], ...detail }
      viewer.detailStatus = 'success'
      // Opening a photo clears its comment, Grr and tag counters.
      useNotificationsStore().markSeen({ targetId: photoId })
    } catch (error) {
      viewer.detailStatus = 'error'
      viewer.detailError = errorMessage(error)
      viewer.detailErrorCode = error?.code ?? null
      viewer.detailOwnerId = error?.details?.ownerId ?? null
    }
  }

  const openViewer = (ids, index = 0) => {
    viewer.ids = [...ids]
    viewer.index = Math.max(0, Math.min(index, ids.length - 1))
    viewer.open = true
    loadDetail(viewer.ids[viewer.index])
  }

  /** Opens a single photo that may not be cached yet (e.g. from a post). */
  const openSingle = async (photoId, siblings = null) => {
    const ids = siblings?.length ? siblings : [photoId]
    viewer.ids = ids
    viewer.index = Math.max(0, ids.indexOf(photoId))
    viewer.open = true
    await loadDetail(photoId)
  }

  const closeViewer = () => {
    viewer.open = false
  }

  const step = (delta) => {
    if (!viewer.open || viewer.ids.length < 2) return
    viewer.index = (viewer.index + delta + viewer.ids.length) % viewer.ids.length
    loadDetail(viewer.ids[viewer.index])
  }

  // ---- Grr, comments, tags -----------------------------------------------

  const toggleGrr = async (photoId) => {
    const photo = photos[photoId]
    if (!photo || grrPending.value.has(photoId)) return
    const next = !photo.hasGrr
    const previous = { hasGrr: photo.hasGrr, grrCount: photo.grrCount }
    photo.hasGrr = next
    photo.grrCount += next ? 1 : -1
    grrPending.value.add(photoId)
    try {
      Object.assign(photo, await interactionsService.setGrr('photo', photoId, next))
      toast.show(next ? 'Grr añadido.' : 'Grr eliminado.', { duration: GRR_TOAST_DURATION_MS })
    } catch (error) {
      Object.assign(photo, previous)
      toast.error(errorMessage(error))
    } finally {
      grrPending.value.delete(photoId)
    }
  }

  // ---- Co-ownership --------------------------------------------------------

  const inviteCoOwners = async (photoId, userIds) => {
    const { photo, invited } = await photosService.inviteCoOwners(photoId, userIds)
    photos[photoId] = { ...photos[photoId], ...photo }
    toast.success(invited ? 'Invitación enviada.' : 'Ya estaban invitados.')
  }

  const respondOwnerInvite = async (photoId, accept) => {
    try {
      const photo = await photosService.respondOwnerInvite(photoId, accept)
      if (photo) photos[photoId] = { ...photos[photoId], ...photo }
      else if (photos[photoId]) photos[photoId].ownerInvite = null
      toast.success(accept ? 'Ahora la foto también es tuya.' : 'Invitación rechazada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const addComment = async (photoId, text) => {
    const comment = await interactionsService.addComment('photo', photoId, text)
    const photo = photos[photoId]
    if (photo) {
      photo.comments = [...(photo.comments ?? []), comment]
      photo.commentCount += 1
    }
    toast.success('Comentario publicado.')
  }

  const deleteComment = async (photoId, commentId) => {
    try {
      await interactionsService.deleteComment(commentId)
      const photo = photos[photoId]
      if (photo) {
        photo.comments = (photo.comments ?? []).filter((c) => c.id !== commentId)
        photo.commentCount -= 1
      }
      toast.success('Comentario eliminado.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const addTag = async (photoId, userId, x, y) => {
    try {
      const tag = await photosService.addTag(photoId, userId, x, y)
      photos[photoId].tags = [...photos[photoId].tags, tag]
      toast.success('Etiqueta añadida.')
      return true
    } catch (error) {
      toast.error(errorMessage(error))
      return false
    }
  }

  const removeTag = async (photoId, tagId) => {
    try {
      await photosService.removeTag(tagId)
      photos[photoId].tags = photos[photoId].tags.filter((t) => t.id !== tagId)
      toast.success('Etiqueta eliminada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return {
    photos,
    albums,
    albumsByUser,
    albumDetail,
    lists,
    viewer,
    currentPhoto,
    grrPending,
    loadAlbums,
    loadAlbum,
    loadUserPhotos,
    loadTaggedPhotos,
    createAlbum,
    updateAlbum,
    deleteAlbum,
    uploadPhotos,
    addToAlbum,
    removeFromAlbum,
    setCover,
    updateCaption,
    deletePhoto,
    openViewer,
    openSingle,
    closeViewer,
    step,
    toggleGrr,
    inviteCoOwners,
    respondOwnerInvite,
    addComment,
    deleteComment,
    addTag,
    removeTag,
  }
})
