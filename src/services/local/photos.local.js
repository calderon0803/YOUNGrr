import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import {
  areFriends,
  canViewPhoto,
  canViewProfile,
  findOr404,
  friendIdsOf,
  isPhotoOwner,
  pendingOwnerInvite,
  photoOwnerIds,
  profileOf,
  summaryOf,
} from '@/services/local/access'
import { dropNotifications, notify } from '@/services/local/notify'
import { albumView, photoView } from '@/services/local/views'
import { removePhotoCascade } from '@/services/local/posts.local'
import { ensure, ensureAccess, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'

const byDateAsc = (a, b) => a.createdAt.localeCompare(b.createdAt)
const byDateDesc = (a, b) => b.createdAt.localeCompare(a.createdAt)

const ownAlbum = (db, me, albumId) => {
  const album = findOr404(db.albums, (a) => a.id === albumId, 'Este álbum ya no existe.')
  ensure(album.ownerId === me, 'forbidden', 'Solo puedes modificar tus álbumes.')
  return album
}

const findPhoto = (db, photoId) => findOr404(db.photos, (p) => p.id === photoId, 'Esta fotografía ya no existe.')

/** Uploader or accepted co-owner: both have the same rights over the photo. */
const ownedPhoto = (db, me, photoId) => {
  const photo = findPhoto(db, photoId)
  ensure(isPhotoOwner(db, me, photo), 'forbidden', 'Solo los dueños de la foto pueden hacer esto.')
  return photo
}

const validateAlbum = ({ title, description }) => {
  validate(
    rules.required(title, 'El nombre del álbum'),
    rules.max(title, LIMITS.albumTitle, 'El nombre del álbum'),
    rules.max(description, LIMITS.albumDescription, 'La descripción'),
  )
}

const wallAlbumOf = (db, userId) => {
  let wall = db.albums.find((a) => a.ownerId === userId && a.kind === 'wall')
  if (!wall) {
    const createdAt = nowIso()
    wall = { id: uid('a'), ownerId: userId, kind: 'wall', title: 'Fotos del muro', description: 'Fotografías publicadas en el muro.', coverPhotoId: null, createdAt, updatedAt: createdAt }
    db.albums.push(wall)
  }
  return wall
}

/** Invites friends to co-own a photo. Returns how many new invitations were sent. */
const inviteOwners = (db, me, photo, userIds) => {
  const taken = new Set([
    ...photoOwnerIds(db, photo),
    ...db.photoOwners.filter((o) => o.photoId === photo.id && o.status === 'pending').map((o) => o.userId),
  ])
  const fresh = [...new Set(userIds)].filter((id) => !taken.has(id))
  fresh.forEach((id) => ensure(areFriends(db, me, id), 'forbidden', 'Solo puedes compartir la foto con tus amigos.'))
  for (const userId of fresh) {
    db.photoOwners = db.photoOwners.filter((o) => !(o.photoId === photo.id && o.userId === userId))
    db.photoOwners.push({ photoId: photo.id, userId, status: 'pending', invitedBy: me, createdAt: nowIso(), respondedAt: null })
  }
  return fresh.length
}

/**
 * Removes the photo from `me`. It is only deleted for good when no owner is
 * left; if the uploader leaves, another owner takes it into their wall album.
 * @returns {'deleted' | 'left'}
 */
const leavePhoto = (db, me, photo) => {
  const others = photoOwnerIds(db, photo).filter((id) => id !== me)
  if (!others.length) {
    removePhotoCascade(db, photo.id)
    return 'deleted'
  }
  if (photo.ownerId === me) {
    const heir = others[0]
    const album = db.albums.find((a) => a.id === photo.albumId)
    if (album?.coverPhotoId === photo.id) album.coverPhotoId = null
    photo.ownerId = heir
    photo.albumId = wallAlbumOf(db, heir).id
    db.photoOwners = db.photoOwners.filter((o) => !(o.photoId === photo.id && o.userId === heir))
  } else {
    db.photoOwners = db.photoOwners.filter((o) => !(o.photoId === photo.id && o.userId === me))
  }
  return 'left'
}

// Photos for the local demo backend. Same interface as photos.supabase.js.
export const localPhotosService = {
  async listAlbums(userId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    profileOf(db, userId)
    ensure(canViewProfile(db, me, userId), 'forbidden', 'Este perfil es privado.')
    return db.albums
      .filter((a) => a.ownerId === userId)
      .map((a) => albumView(db, a, me))
      .filter((a) => a.kind === 'user' || a.photoCount > 0)
      .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
  },

  async getAlbum(albumId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const album = findOr404(db.albums, (a) => a.id === albumId, 'Este álbum ya no existe.')
    ensureAccess(canViewProfile(db, me, album.ownerId), album.ownerId)
    return {
      album: albumView(db, album, me),
      // A co-owner's privacy can hide some photos of the album.
      photos: db.photos
        .filter((p) => p.albumId === albumId && canViewPhoto(db, me, p))
        .sort(byDateAsc)
        .map((p) => photoView(db, me, p)),
      canEdit: album.ownerId === me,
    }
  },

  async createAlbum(input) {
    validateAlbum(input)
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const createdAt = nowIso()
    const album = { id: uid('a'), ownerId: me, kind: 'user', title: input.title.trim(), description: input.description.trim(), coverPhotoId: null, createdAt, updatedAt: createdAt }
    db.albums.push(album)
    await commit()
    return albumView(db, album, me)
  },

  async updateAlbum(albumId, input) {
    validateAlbum(input)
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const album = ownAlbum(db, me, albumId)
    ensure(album.kind === 'user', 'forbidden', 'Este álbum no se puede renombrar.')
    album.title = input.title.trim()
    album.description = input.description.trim()
    album.updatedAt = nowIso()
    await commit()
    return albumView(db, album, me)
  },

  /** Photos shared with co-owners are not lost: they move to the other owner. */
  async deleteAlbum(albumId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const album = ownAlbum(db, me, albumId)
    ensure(album.kind === 'user', 'forbidden', 'Este álbum no se puede eliminar.')
    for (const photo of db.photos.filter((p) => p.albumId === albumId)) leavePhoto(db, me, photo)
    db.albums = db.albums.filter((a) => a.id !== albumId)
    db.posts = db.posts.filter((p) => p.albumId !== albumId)
    await commit()
  },

  async setCover(albumId, photoId) {
    await latency(80, 160)
    const db = await getDb()
    const me = requireUserId(db)
    const album = ownAlbum(db, me, albumId)
    ensure(db.photos.some((p) => p.id === photoId && p.albumId === albumId), 'not_found', 'La foto no está en este álbum.')
    album.coverPhotoId = photoId
    await commit()
    return albumView(db, album, me)
  },

  /**
   * @param {{ dataUrl: string, width: number, height: number, caption: string }[]} items
   * @param {string[]} coOwnerIds friends invited to co-own every uploaded photo
   */
  async addPhotos(albumId, items, coOwnerIds = []) {
    validate(items.length ? null : 'Elige al menos una fotografía.')
    items.forEach((item) => validate(rules.max(item.caption, LIMITS.caption, 'El pie de foto')))
    await latency(250, 500)
    const db = await getDb()
    const me = requireUserId(db)
    const album = ownAlbum(db, me, albumId)
    coOwnerIds.forEach((id) => ensure(areFriends(db, me, id), 'forbidden', 'Solo puedes compartir la foto con tus amigos.'))
    const createdAt = nowIso()
    const added = items.map((item, i) => {
      const photo = {
        id: uid('ph'),
        ownerId: me,
        albumId,
        url: item.dataUrl,
        width: item.width,
        height: item.height,
        caption: item.caption.trim(),
        // Keep upload order stable.
        createdAt: new Date(Date.parse(createdAt) + i).toISOString(),
      }
      db.photos.push(photo)
      inviteOwners(db, me, photo, coOwnerIds)
      return photo
    })
    album.updatedAt = createdAt
    // "X ha subido N fotos al álbum Y" in the friends' news.
    if (album.kind === 'user') {
      db.posts.push({ id: uid('p'), authorId: me, kind: 'album_upload', albumId, photoIds: added.map((p) => p.id), text: '', photoId: null, createdAt, updatedAt: null })
    }
    await commit()
    return added.map((p) => photoView(db, me, p))
  },

  async updateCaption(photoId, caption) {
    validate(rules.max(caption, LIMITS.caption, 'El pie de foto'))
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const photo = ownedPhoto(db, me, photoId)
    photo.caption = caption.trim()
    await commit()
    return photoView(db, me, photo)
  },

  /** Removes the photo from your profile; it disappears only when no owner is left. */
  async deletePhoto(photoId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const result = leavePhoto(db, me, ownedPhoto(db, me, photoId))
    await commit()
    return result
  },

  // ---- Co-ownership ---------------------------------------------------------

  async inviteCoOwners(photoId, userIds) {
    validate(userIds.length ? null : 'Elige al menos a una persona.')
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const photo = ownedPhoto(db, me, photoId)
    const invited = inviteOwners(db, me, photo, userIds)
    await commit()
    return { photo: photoView(db, me, photo, { withComments: true }), invited }
  },

  /** The invited friend accepts (same rights as the uploader) or declines. */
  async respondOwnerInvite(photoId, accept) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const photo = findPhoto(db, photoId)
    const invite = pendingOwnerInvite(db, me, photo)
    ensure(invite, 'not_found', 'Esta invitación ya no está disponible.')
    invite.status = accept ? 'accepted' : 'rejected'
    invite.respondedAt = nowIso()
    dropNotifications(db, (n) => n.type === 'photo_owner_invite' && n.userId === me && n.targetId === photoId)
    if (accept) notify(db, { userId: invite.invitedBy, actorId: me, type: 'photo_owner_accepted', targetId: photoId })
    await commit()
    return canViewPhoto(db, me, photo) ? photoView(db, me, photo, { withComments: true }) : null
  },

  async getPhoto(photoId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const photo = findPhoto(db, photoId)
    ensureAccess(canViewPhoto(db, me, photo), photo.ownerId)
    return photoView(db, me, photo, { withComments: true })
  },

  /** Photos someone owns: uploaded by them or shared with them as co-owner. */
  async listUserPhotos(userId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(canViewProfile(db, me, userId), 'forbidden', 'Este perfil es privado.')
    return db.photos
      .filter((p) => isPhotoOwner(db, userId, p) && canViewPhoto(db, me, p))
      .sort(byDateDesc)
      .map((p) => photoView(db, me, p))
  },

  /**
   * Photos where someone appears tagged (only friends can tag). Each photo
   * follows its owners' profile privacy.
   */
  async listTaggedPhotos(userId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    profileOf(db, userId)
    ensure(canViewProfile(db, me, userId), 'forbidden', 'Este perfil es privado.')
    const ids = new Set(db.photoTags.filter((t) => t.userId === userId).map((t) => t.photoId))
    return db.photos
      .filter((p) => ids.has(p.id) && canViewPhoto(db, me, p))
      .sort(byDateDesc)
      .map((p) => photoView(db, me, p))
  },

  /** Latest photos from friends, for the Photos page. */
  async listFriendsPhotos({ limit = 24 } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const friends = new Set(friendIdsOf(db, me))
    return db.photos
      .filter((p) => photoOwnerIds(db, p).some((id) => friends.has(id)) && !isPhotoOwner(db, me, p) && canViewPhoto(db, me, p))
      .sort(byDateDesc)
      .slice(0, limit)
      .map((p) => photoView(db, me, p))
  },

  /** Only the photo's owners can tag, each one themselves or their own friends. */
  async addTag(photoId, userId, x, y) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const photo = findPhoto(db, photoId)
    ensure(isPhotoOwner(db, me, photo), 'forbidden', 'Solo pueden etiquetar los dueños de la foto.')
    ensure(userId === me || areFriends(db, me, userId), 'forbidden', 'Solo puedes etiquetar a tus amigos.')
    ensure(!db.photoTags.some((t) => t.photoId === photoId && t.userId === userId), 'conflict', 'Esta persona ya está etiquetada en la foto.')
    validate(x >= 0 && x <= 1 && y >= 0 && y <= 1 ? null : 'Posición de etiqueta no válida.')

    const tag = { id: uid('t'), photoId, userId, taggedBy: me, x, y, createdAt: nowIso() }
    db.photoTags.push(tag)
    notify(db, { userId, actorId: me, type: 'photo_tag', targetId: photoId })
    await commit()
    return { ...tag, person: summaryOf(db, userId) }
  },

  async removeTag(tagId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const tag = findOr404(db.photoTags, (t) => t.id === tagId, 'La etiqueta ya no existe.')
    const photo = findPhoto(db, tag.photoId)
    ensure(tag.userId === me || isPhotoOwner(db, me, photo), 'forbidden', 'No puedes quitar esta etiqueta.')
    db.photoTags = db.photoTags.filter((t) => t.id !== tagId)
    dropNotifications(db, (n) => n.type === 'photo_tag' && n.userId === tag.userId && n.targetId === tag.photoId)
    await commit()
  },
}
