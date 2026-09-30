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

/** A block in either direction (only the blocker knows about it). */
export const isBlockedBetween = (db, a, b) =>
  (db.blocks ?? []).some((x) => (x.blockerId === a && x.blockedId === b) || (x.blockerId === b && x.blockedId === a))

/**
 * What `ownerId` shows in the groups they share with `viewer`, for people who
 * are not friends: 0 name and photo, 1 information, 2 whole profile.
 */
export const groupShare = (db, viewer, ownerId) => {
  if (viewer === ownerId || areFriends(db, viewer, ownerId)) return 0
  const LEVEL = { basic: 0, info: 1, full: 2 }
  const mine = new Set((db.groupMembers ?? []).filter((m) => m.userId === viewer).map((m) => m.groupId))
  return Math.max(0, ...(db.groupMembers ?? []).filter((m) => m.userId === ownerId && mine.has(m.groupId)).map((m) => LEVEL[m.profileShare ?? 'basic']))
}

export const canViewProfile = (db, viewer, ownerId) =>
  !isBlockedBetween(db, viewer, ownerId) &&
  (allowedBy(db, viewer, ownerId, settingsOf(db, ownerId).privacy.profileVisibility) || groupShare(db, viewer, ownerId) === 2)

/** Town, studies, work and birthday: the whole profile, or a group sharing them. */
export const canViewInfo = (db, viewer, ownerId) =>
  canViewProfile(db, viewer, ownerId) || (!isBlockedBetween(db, viewer, ownerId) && groupShare(db, viewer, ownerId) >= 1)

/** Who sees the town of a profile (profile and people lists). */
export const canViewCity = (db, viewer, ownerId) =>
  (canViewProfile(db, viewer, ownerId) && allowedBy(db, viewer, ownerId, settingsOf(db, ownerId).privacy.cityVisibility ?? 'friends')) ||
  (!isBlockedBetween(db, viewer, ownerId) && groupShare(db, viewer, ownerId) >= 1)

export const visibleCity = (db, viewer, profile) => (canViewCity(db, viewer, profile.id) ? profile.city : '')

export const canSendRequest = (db, me, other) => {
  if (friendshipStatus(db, me, other) !== 'none' || isBlockedBetween(db, me, other)) return false
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

// ---- Groups ------------------------------------------------------------------

/** 'owner' | 'admin' | 'member', or null when not in the group. */
export const groupRole = (db, groupId, userId) =>
  (db.groupMembers ?? []).find((m) => m.groupId === groupId && m.userId === userId)?.role ?? null

export const isGroupMember = (db, groupId, userId) => groupRole(db, groupId, userId) !== null

/** Also the moderators who are in a place group. */
export const isGroupAdmin = (db, groupId, userId) => {
  const role = groupRole(db, groupId, userId)
  if (role === 'owner' || role === 'admin') return true
  return !!role && (db.moderators ?? []).includes(userId) && db.groups?.find((g) => g.id === groupId)?.kind === 'place'
}

export const groupMemberCount = (db, groupId) => (db.groupMembers ?? []).filter((m) => m.groupId === groupId).length
