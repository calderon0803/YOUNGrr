// Database rows (snake_case) to the app's model (camelCase), see types/models.js.

/** @returns {import('@/types/models').Profile} */
export const toProfile = (row) => ({
  id: row.id,
  firstName: row.first_name,
  lastName: row.last_name,
  avatarUrl: row.avatar_url ?? null,
  coverUrl: row.cover_url ?? null,
  city: row.city ?? '',
  cityLat: row.city_lat ?? null,
  cityLng: row.city_lng ?? null,
  bio: row.bio ?? '',
  birthday: row.birthday ?? null,
  studies: row.studies ?? '',
  work: row.work ?? '',
  visitCount: row.visit_count ?? 0,
  createdAt: row.created_at,
})

/** @returns {import('@/types/models').PersonView} */
export const toPerson = (json) => ({
  id: json.id,
  firstName: json.first_name,
  lastName: json.last_name,
  avatarUrl: json.avatar_url ?? null,
  city: json.city ?? '',
  friendship: json.friendship,
  mutualFriends: json.mutual_friends ?? 0,
  canSendRequest: !!json.can_send_request,
})

/** @returns {import('@/types/models').ProfileView} */
export const toProfileView = (json) => ({
  profile: toProfile(json.profile),
  friendship: json.friendship,
  friendsCount: json.friends_count ?? 0,
  mutualFriends: json.mutual_friends ?? 0,
  postsCount: json.posts_count ?? 0,
  photosCount: json.photos_count ?? 0,
  canViewProfile: !!json.can_view_profile,
  canSendRequest: !!json.can_send_request,
  // Only present on your own profile.
  visits: json.visits ?? null,
  // Latest text-only post, shown as the profile status.
  status: json.status ? { postId: json.status.post_id, text: json.status.text, createdAt: json.status.created_at } : null,
})

export const toFriendRequest = (json) => {
  const person = toPerson(json.person)
  return {
    id: json.id,
    person: { id: person.id, firstName: person.firstName, lastName: person.lastName, avatarUrl: person.avatarUrl, city: person.city },
    mutualFriends: person.mutualFriends,
    createdAt: json.created_at,
  }
}

/** user_settings row → app settings (see UserSettings in types/models.js). */
export const toSettings = (row) => ({
  privacy: {
    profileVisibility: row.profile_visibility,
    cityVisibility: row.city_visibility,
    distanceVisibility: row.distance_visibility,
    friendRequests: row.friend_requests,
  },
  notifications: {
    grr: row.notify_grr,
    comments: row.notify_comments,
    friendRequests: row.notify_friend_requests,
    events: row.notify_events,
    messages: row.notify_messages,
    tags: row.notify_tags,
  },
  appearance: { theme: row.theme },
  nearby: { radiusKm: row.nearby_radius_km },
})

export const fromSettings = (settings) => ({
  profile_visibility: settings.privacy.profileVisibility,
  city_visibility: settings.privacy.cityVisibility,
  distance_visibility: settings.privacy.distanceVisibility,
  friend_requests: settings.privacy.friendRequests,
  notify_grr: settings.notifications.grr,
  notify_comments: settings.notifications.comments,
  notify_friend_requests: settings.notifications.friendRequests,
  notify_events: settings.notifications.events,
  notify_messages: settings.notifications.messages,
  notify_tags: settings.notifications.tags,
  theme: settings.appearance.theme,
  nearby_radius_km: settings.nearby.radiusKm,
})

const toSummary = (json) => ({
  id: json.id,
  firstName: json.first_name,
  lastName: json.last_name,
  avatarUrl: json.avatar_url ?? null,
})

/** @returns {import('@/types/models').CommentView} */
export const toComment = (json) => ({
  id: json.id,
  targetType: json.target_type,
  targetId: json.target_id,
  authorId: json.author_id,
  text: json.text,
  createdAt: json.created_at,
  author: toSummary(json.author),
})

/**
 * @param {object} json post_json() from the database
 * @param {Record<string, string>} urls signed URLs by Storage path
 * @returns {import('@/types/models').PostView}
 */
export const toPost = (json, urls = {}) => ({
  id: json.id,
  authorId: json.author_id,
  text: json.text,
  photoId: json.photo_id,
  createdAt: json.created_at,
  updatedAt: json.updated_at,
  author: toSummary(json.author),
  photo: json.photo
    ? {
        id: json.photo.id,
        url: urls[json.photo.storage_path] ?? null,
        width: json.photo.width,
        height: json.photo.height,
        albumId: json.photo.album_id,
      }
    : null,
  // "Ha subido N fotos al álbum X" items.
  kind: json.kind ?? 'post',
  album: json.album ? { id: json.album.id, title: json.album.title } : null,
  photos: (json.photos ?? []).map((p) => ({ id: p.id, url: urls[p.storage_path] ?? null, width: p.width, height: p.height })),
  photoTotal: json.photo_total ?? 0,
  grrCount: json.grr_count,
  hasGrr: json.has_grr,
  grrBy: json.grr_by.map(toSummary),
  commentCount: json.comment_count,
  comments: json.comments.map(toComment),
})

/** Storage paths of every photo a post references (single photo or album upload). */
export const postPhotoPaths = (json) => [json.photo?.storage_path, ...(json.photos ?? []).map((p) => p.storage_path)]

/** @returns {import('@/types/models').PhotoView} */
export const toPhoto = (json, urls = {}) => ({
  id: json.id,
  ownerId: json.owner_id,
  albumId: json.album_id,
  url: urls[json.storage_path] ?? null,
  width: json.width,
  height: json.height,
  caption: json.caption ?? '',
  createdAt: json.created_at,
  owner: toSummary(json.owner),
  owners: (json.owners ?? []).map(toSummary),
  isOwner: !!json.is_owner,
  isUploader: !!json.is_uploader,
  pendingOwners: (json.pending_owners ?? []).map(toSummary),
  ownerInvite: json.owner_invite ? { invitedBy: toSummary(json.owner_invite.invited_by) } : null,
  albumTitle: json.album_title ?? '',
  albumAccessible: !!json.album_accessible,
  grrCount: json.grr_count,
  hasGrr: json.has_grr,
  commentCount: json.comment_count,
  tags: (json.tags ?? []).map((t) => ({
    id: t.id,
    photoId: t.photo_id,
    userId: t.user_id,
    taggedBy: t.tagged_by,
    x: t.x,
    y: t.y,
    createdAt: t.created_at,
    person: toSummary(t.person),
  })),
  ...(json.comments ? { comments: json.comments.map(toComment) } : {}),
})

/** @returns {import('@/types/models').AlbumView} */
export const toAlbum = (json, urls = {}) => ({
  id: json.id,
  ownerId: json.owner_id,
  kind: json.kind,
  title: json.title,
  description: json.description ?? '',
  coverPhotoId: json.cover_photo_id,
  createdAt: json.created_at,
  updatedAt: json.updated_at,
  owner: toSummary(json.owner),
  coverUrl: urls[json.cover_path] ?? null,
  photoCount: json.photo_count ?? 0,
})

export { toSummary }

export const toWallMessage = (json) => ({
  id: json.id,
  profileId: json.profile_id,
  authorId: json.author_id,
  text: json.text,
  createdAt: json.created_at,
  author: toSummary(json.author),
})

export const toBirthday = (json) => ({ person: toSummary(json.person), date: json.date, daysLeft: json.days_left })
