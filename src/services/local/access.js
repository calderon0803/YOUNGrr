// Relationship and privacy rules. In Supabase these are the RLS policies and
// SQL helpers (are_friends, can_view_profile...) from supabase/migrations.
import { fail } from '@/services/errors'

export const pairKey = (a, b) => (a < b ? [a, b] : [b, a])

export const areFriends = (db, a, b) => {
  if (a === b) return false
  const [x, y] = pairKey(a, b)
  return db.friendships.some((f) => f.userA === x && f.userB === y)
}

export const friendIdsOf = (db, id) => {
  const ids = []
  for (const f of db.friendships) {
    if (f.userA === id) ids.push(f.userB)
    else if (f.userB === id) ids.push(f.userA)
  }
  return ids
}

export const mutualFriends = (db, a, b) => {
  if (a === b) return 0
  const mine = new Set(friendIdsOf(db, a))
  return friendIdsOf(db, b).filter((id) => mine.has(id)).length
}

export const pendingRequest = (db, fromId, toId) => {
  return db.friendRequests.find((r) => r.fromId === fromId && r.toId === toId && r.status === 'pending')
}

export const friendshipStatus = (db, me, other) => {
  if (me === other) return 'self'
  if (areFriends(db, me, other)) return 'friends'
  if (pendingRequest(db, me, other)) return 'request_sent'
  if (pendingRequest(db, other, me)) return 'request_received'
  return 'none'
}

export const settingsOf = (db, id) => {
  return db.settings[id]
}

const allowedBy = (db, viewer, ownerId, visibility) => {
  if (viewer === ownerId) return true
  if (visibility === 'everyone') return true
  if (visibility === 'friends') return areFriends(db, viewer, ownerId)
  return false
}

export const canViewProfile = (db, viewer, ownerId) =>
  allowedBy(db, viewer, ownerId, settingsOf(db, ownerId).privacy.profileVisibility)

/** Town (profile, people lists, "Cerca de ti") and distance ("Cerca de ti") have separate settings. */
export const canViewCity = (db, viewer, ownerId) =>
  canViewProfile(db, viewer, ownerId) && allowedBy(db, viewer, ownerId, settingsOf(db, ownerId).privacy.cityVisibility ?? 'friends')

export const canViewDistance = (db, viewer, ownerId) =>
  canViewProfile(db, viewer, ownerId) && allowedBy(db, viewer, ownerId, settingsOf(db, ownerId).privacy.distanceVisibility ?? 'friends')

/** Coordinates never leave the backend, except to their owner. */
export const visibleCity = (db, viewer, profile) => (canViewCity(db, viewer, profile.id) ? profile.city : '')

export const canSendRequest = (db, me, other) => {
  if (friendshipStatus(db, me, other) !== 'none') return false
  const policy = settingsOf(db, other).privacy.friendRequests
  if (policy === 'nobody') return false
  if (policy === 'friends_of_friends') return mutualFriends(db, me, other) > 0
  return true
}

/** Account and profile share one privacy setting: posts are visible to whoever can see the account. */
export const canViewPost = (db, viewer, post) => canViewProfile(db, viewer, post.authorId)

// ---- Photo ownership ------------------------------------------------------
// `photo.ownerId` is the uploader (the photo lives in their album). Accepted
// co-owners in `photoOwners` have the same rights, except managing that album.

/** Everyone who owns the photo: uploader first, then accepted co-owners. */
export const photoOwnerIds = (db, photo) => [
  photo.ownerId,
  ...db.photoOwners.filter((o) => o.photoId === photo.id && o.status === 'accepted').map((o) => o.userId),
]

export const isPhotoOwner = (db, userId, photo) => photoOwnerIds(db, photo).includes(userId)

export const pendingOwnerInvite = (db, userId, photo) =>
  db.photoOwners.find((o) => o.photoId === photo.id && o.userId === userId && o.status === 'pending')

/**
 * Photos have no permissions of their own: they follow the profile privacy of
 * their owners ("Quién puede ver mi perfil"). A co-owned photo is shown in
 * every owner's profile, so whoever can see any of those profiles sees it.
 * Tagged people need no exception: only friends can tag you.
 */
export const canViewPhoto = (db, viewer, photo) =>
  photoOwnerIds(db, photo).some((ownerId) => ownerId === viewer || canViewProfile(db, viewer, ownerId))

export const findOr404 = (list, predicate, message) => {
  const item = list.find(predicate)
  if (!item) fail('not_found', message)
  return item
}

export const profileOf = (db, id) => {
  return findOr404(db.profiles, (p) => p.id === id, 'Esta persona no existe o ha eliminado su cuenta.')
}

export const summaryOf = (db, id) => {
  const p = profileOf(db, id)
  return { id: p.id, firstName: p.firstName, lastName: p.lastName, avatarUrl: p.avatarUrl }
}

export const personView = (db, me, id) => {
  const p = profileOf(db, id)
  return {
    ...summaryOf(db, id),
    city: visibleCity(db, me, p),
    friendship: friendshipStatus(db, me, id),
    mutualFriends: mutualFriends(db, me, id),
    canSendRequest: canSendRequest(db, me, id),
  }
}
