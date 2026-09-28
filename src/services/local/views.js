// Builds the view models the UI consumes (joins + counters), as a SQL view would.
import { canViewPhoto, canViewProfile, friendIdsOf, pendingOwnerInvite, photoOwnerIds, summaryOf } from '@/services/local/access'
import { ACTIVITY_LIMITS, ALBUM_UPLOAD_PREVIEW, COMMENT_PREVIEW } from '@/config/app'

const byDateAsc = (a, b) => a.createdAt.localeCompare(b.createdAt)

export const grrState = (db, me, targetType, targetId) => {
  const grrs = db.grrs.filter((g) => g.targetType === targetType && g.targetId === targetId)
  return { grrCount: grrs.length, hasGrr: grrs.some((g) => g.userId === me) }
}

export const commentsOf = (db, targetType, targetId) => {
  return db.comments
    .filter((c) => c.targetType === targetType && c.targetId === targetId)
    .sort(byDateAsc)
    .map((c) => ({ ...c, author: summaryOf(db, c.authorId) }))
}

export const postView = (db, me, post, { commentPreview = COMMENT_PREVIEW } = {}) => {
  const photo = post.photoId ? db.photos.find((p) => p.id === post.photoId) : null
  const comments = commentsOf(db, 'post', post.id)
  const grrs = db.grrs.filter((g) => g.targetType === 'post' && g.targetId === post.id)
  // Friends first in "Ana, Pablo y 3 más".
  const myFriends = new Set(friendIdsOf(db, me))
  const grrBy = grrs
    .filter((g) => g.userId !== me)
    .sort((a, b) => Number(myFriends.has(b.userId)) - Number(myFriends.has(a.userId)))
    .slice(0, 2)
    .map((g) => summaryOf(db, g.userId))

  // "Ha subido N fotos al álbum X": the photos that still exist, up to six.
  const uploaded = post.kind === 'album_upload' ? (post.photoIds ?? []).map((id) => db.photos.find((p) => p.id === id)).filter(Boolean) : []
  const album = post.albumId ? db.albums.find((a) => a.id === post.albumId) : null

  return {
    ...post,
    kind: post.kind ?? 'status',
    album: album ? { id: album.id, title: album.title } : null,
    photos: uploaded.slice(0, ALBUM_UPLOAD_PREVIEW).map((p) => ({ id: p.id, url: p.url, width: p.width, height: p.height })),
    photoTotal: uploaded.length,
    author: summaryOf(db, post.authorId),
    photo: photo
      ? { id: photo.id, url: photo.url, width: photo.width, height: photo.height, albumId: photo.albumId }
      : null,
    grrCount: grrs.length,
    hasGrr: grrs.some((g) => g.userId === me),
    grrBy,
    commentCount: comments.length,
    comments: commentPreview === Infinity ? comments : comments.slice(-commentPreview),
  }
}

/**
 * One person's block in the friends' news: current status, recent album
 * uploads and, for friends, new friendships and photos where they were tagged
 * (that the viewer can see). Same shape as activity_block_json().
 */
export const activityBlock = (db, me, personId, { since, withSocial, lastActivityAt }) => {
  const newest = (a, b) => b.createdAt.localeCompare(a.createdAt)
  const status = db.posts.find((p) => p.authorId === personId && (p.kind ?? 'status') === 'status')
  const uploads = db.posts.filter((p) => p.authorId === personId && p.kind === 'album_upload' && p.createdAt >= since).sort(newest)
  const friendships = withSocial
    ? db.friendships
        .filter((f) => [f.userA, f.userB].includes(personId) && ![f.userA, f.userB].includes(me) && f.createdAt >= since)
        .sort(newest)
    : []
  const tags = withSocial
    ? db.photoTags
        .filter((t) => t.userId === personId && t.createdAt >= since)
        .map((t) => ({ tag: t, photo: db.photos.find((p) => p.id === t.photoId) }))
        .filter(({ photo }) => photo && canViewPhoto(db, me, photo))
        .sort((a, b) => newest(a.tag, b.tag))
    : []
  return {
    person: summaryOf(db, personId),
    lastActivityAt,
    status: status ? postView(db, me, status) : null,
    uploads: uploads.slice(0, ACTIVITY_LIMITS.uploads).map((p) => postView(db, me, p)),
    newFriends: friendships.slice(0, ACTIVITY_LIMITS.newFriends).map((f) => ({
      person: summaryOf(db, f.userA === personId ? f.userB : f.userA),
      createdAt: f.createdAt,
    })),
    newFriendsTotal: friendships.length,
    tagged: tags.slice(0, ACTIVITY_LIMITS.tagged).map(({ photo }) => ({ id: photo.id, url: photo.url, width: photo.width, height: photo.height })),
    taggedTotal: tags.length,
  }
}

export const photoView = (db, me, photo, { withComments = false } = {}) => {
  const album = db.albums.find((a) => a.id === photo.albumId)
  const comments = commentsOf(db, 'photo', photo.id)
  const ownerIds = photoOwnerIds(db, photo)
  const invite = pendingOwnerInvite(db, me, photo)
  const view = {
    ...photo,
    owner: summaryOf(db, photo.ownerId),
    /** Uploader first, then accepted co-owners; all with the same rights. */
    owners: ownerIds.map((id) => summaryOf(db, id)),
    isOwner: ownerIds.includes(me),
    isUploader: photo.ownerId === me,
    /** Co-ownership invitations still waiting for an answer (visible to owners). */
    pendingOwners: ownerIds.includes(me)
      ? db.photoOwners.filter((o) => o.photoId === photo.id && o.status === 'pending').map((o) => summaryOf(db, o.userId))
      : [],
    /** Set when the viewer has been invited to co-own this photo. */
    ownerInvite: invite ? { invitedBy: summaryOf(db, invite.invitedBy) } : null,
    albumTitle: album?.title ?? '',
    // Tagged people and post readers may see a photo without access to its album.
    albumAccessible: canViewProfile(db, me, photo.ownerId),
    ...grrState(db, me, 'photo', photo.id),
    commentCount: comments.length,
    tags: db.photoTags
      .filter((t) => t.photoId === photo.id)
      .sort(byDateAsc)
      .map((t) => ({ ...t, person: summaryOf(db, t.userId) })),
  }
  if (withComments) view.comments = comments
  return view
}

/** Counts and cover only include the photos the viewer may see (co-owner privacy). */
export const albumView = (db, album, me) => {
  const photos = db.photos.filter((p) => p.albumId === album.id && canViewPhoto(db, me, p)).sort(byDateAsc)
  const cover = photos.find((p) => p.id === album.coverPhotoId) ?? photos[photos.length - 1] ?? null
  return {
    ...album,
    owner: summaryOf(db, album.ownerId),
    coverUrl: cover?.url ?? null,
    photoCount: photos.length,
  }
}

const RSVP_ORDER = { going: 0, maybe: 1, pending: 2, declined: 3 }

export const eventView = (db, me, event) => {
  const members = db.eventMembers.filter((m) => m.eventId === event.id)
  const counts = { going: 0, maybe: 0, declined: 0, pending: 0 }
  for (const m of members) counts[m.status] += 1

  return {
    ...event,
    creator: summaryOf(db, event.creatorId),
    isCreator: event.creatorId === me,
    myStatus: members.find((m) => m.userId === me)?.status ?? null,
    counts,
    members: members
      .map((m) => ({ person: summaryOf(db, m.userId), status: m.status }))
      .sort((a, b) => RSVP_ORDER[a.status] - RSVP_ORDER[b.status]),
  }
}

export const canSeeEvent = (db, me, event) => {
  return event.creatorId === me || db.eventMembers.some((m) => m.eventId === event.id && m.userId === me)
}
