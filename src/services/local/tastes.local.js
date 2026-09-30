// Tastes for the local demo backend. Same interface as tastes.supabase.js.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { canViewProfile } from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { TASTES } from '@/config/app'

const KIND_ORDER = { artist: 0, movie: 1, series: 2 }

const validRating = (kind, rating) => kind === 'artist' || (rating >= 0.5 && rating <= 5 && Number.isInteger(rating * 2))

export const tasteView = ({ userId, createdAt, ...taste }) => ({ ...taste })

export const localTastesService = {
  async list(userId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(canViewProfile(db, me, userId), 'forbidden', 'No puedes ver los gustos de esta persona.')
    return db.tastes
      .filter((t) => t.userId === userId)
      .sort((a, b) => KIND_ORDER[a.kind] - KIND_ORDER[b.kind] || (b.rating ?? 0) - (a.rating ?? 0) || b.updatedAt.localeCompare(a.updatedAt))
      .map(tasteView)
  },

  async set(kind, item, rating = null) {
    validate(validRating(kind, rating) ? null : 'Elige de media a cinco estrellas.')
    await latency(80, 180)
    const db = await getDb()
    const me = requireUserId(db)
    const now = nowIso()
    let taste = db.tastes.find((t) => t.userId === me && t.kind === kind && t.source === item.source && t.externalId === item.externalId)
    if (taste) Object.assign(taste, { rating: kind === 'artist' ? null : rating, updatedAt: now })
    else {
      ensure(db.tastes.filter((t) => t.userId === me && t.kind === kind).length < TASTES.max, 'conflict', `Has llegado al máximo de ${TASTES.max}.`)
      taste = {
        id: uid('ts'),
        userId: me,
        kind,
        source: item.source,
        externalId: item.externalId,
        title: item.title,
        year: item.year ?? null,
        imagePath: item.imagePath ?? null,
        rating: kind === 'artist' ? null : rating,
        createdAt: now,
        updatedAt: now,
      }
      db.tastes.push(taste)
    }
    await commit()
    return tasteView(taste)
  },

  async remove(tasteId) {
    const db = await getDb()
    const me = requireUserId(db)
    db.tastes = db.tastes.filter((t) => !(t.id === tasteId && t.userId === me))
    await commit()
  },
}
