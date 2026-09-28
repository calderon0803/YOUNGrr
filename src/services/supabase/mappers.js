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
