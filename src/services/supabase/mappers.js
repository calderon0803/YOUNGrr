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
