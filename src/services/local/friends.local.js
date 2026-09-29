import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import {
  canSendRequest,
  canViewProfile,
  friendIdsOf,
  mutualFriends,
  pairKey,
  pendingRequest,
  personView,
  profileOf,
  summaryOf,
  visibleCity,
} from '@/services/local/access'
import { dropNotifications, notify } from '@/services/local/notify'
import { ensure } from '@/services/errors'
import { uid } from '@/utils/ids'
import { nowIso, toDateInput } from '@/utils/time'

const requestView = (db, me, request, otherId) => {
  const p = profileOf(db, otherId)
  return {
    id: request.id,
    person: { id: p.id, firstName: p.firstName, lastName: p.lastName, avatarUrl: p.avatarUrl, city: visibleCity(db, me, p) },
    mutualFriends: mutualFriends(db, me, otherId),
    createdAt: request.createdAt,
  }
}

const makeFriends = (db, a, b) => {
  const [userA, userB] = pairKey(a, b)
  db.friendships.push({ userA, userB, createdAt: nowIso() })
}

// Friends for the local demo backend. Same interface as friends.supabase.js.
export const localFriendsService = {
  async listFriends(userId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(canViewProfile(db, me, userId), 'forbidden', 'Este perfil es privado.')
    return friendIdsOf(db, userId)
      .map((id) => personView(db, me, id))
      .sort((a, b) => a.firstName.localeCompare(b.firstName, 'es'))
  },

  async listRequests() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const pending = db.friendRequests.filter((r) => r.status === 'pending')
    const newestFirst = (a, b) => b.createdAt.localeCompare(a.createdAt)
    return {
      incoming: pending.filter((r) => r.toId === me).sort(newestFirst).map((r) => requestView(db, me, r, r.fromId)),
      outgoing: pending.filter((r) => r.fromId === me).sort(newestFirst).map((r) => requestView(db, me, r, r.toId)),
    }
  },

  async sendRequest(toId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    profileOf(db, toId)
    // If they had already asked us, sending a request means accepting it.
    if (pendingRequest(db, toId, me)) return this.acceptRequest(toId)
    ensure(canSendRequest(db, me, toId), 'forbidden', 'Esta persona no acepta solicitudes de amistad ahora mismo.')

    const request = { id: uid('fr'), fromId: me, toId, status: 'pending', createdAt: nowIso(), respondedAt: null }
    db.friendRequests.push(request)
    await commit()
    return personView(db, me, toId)
  },

  async cancelRequest(toId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const request = pendingRequest(db, me, toId)
    ensure(request, 'not_found', 'La solicitud ya no existe.')
    request.status = 'cancelled'
    request.respondedAt = nowIso()
    dropNotifications(db, (n) => n.type === 'friend_request' && n.userId === toId && n.actorId === me)
    await commit()
    return personView(db, me, toId)
  },

  async acceptRequest(fromId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const request = pendingRequest(db, fromId, me)
    ensure(request, 'not_found', 'La solicitud ya no existe.')
    request.status = 'accepted'
    request.respondedAt = nowIso()
    makeFriends(db, me, fromId)
    notify(db, { userId: fromId, actorId: me, type: 'friend_accepted', targetId: me })
    await commit()
    return personView(db, me, fromId)
  },

  async rejectRequest(fromId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const request = pendingRequest(db, fromId, me)
    ensure(request, 'not_found', 'La solicitud ya no existe.')
    request.status = 'rejected'
    request.respondedAt = nowIso()
    await commit()
    return personView(db, me, fromId)
  },

  async removeFriend(otherId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const [userA, userB] = pairKey(me, otherId)
    const before = db.friendships.length
    db.friendships = db.friendships.filter((f) => !(f.userA === userA && f.userB === userB))
    ensure(db.friendships.length < before, 'not_found', 'No sois amigos.')
    await commit()
    return personView(db, me, otherId)
  },

  /** Blocking: no friendship, requests or messages in either direction. */
  async blockUser(otherId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(otherId !== me, 'validation', 'No puedes bloquearte a ti.')
    profileOf(db, otherId)
    if (!db.blocks.some((b) => b.blockerId === me && b.blockedId === otherId)) db.blocks.push({ blockerId: me, blockedId: otherId, createdAt: nowIso() })
    const [userA, userB] = pairKey(me, otherId)
    db.friendships = db.friendships.filter((f) => !(f.userA === userA && f.userB === userB))
    db.friendRequests = db.friendRequests.filter((r) => !(r.status === 'pending' && [r.fromId, r.toId].includes(me) && [r.fromId, r.toId].includes(otherId)))
    dropNotifications(db, (n) => (n.userId === me && n.actorId === otherId) || (n.userId === otherId && n.actorId === me))
    await commit()
  },

  async unblockUser(otherId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    db.blocks = db.blocks.filter((b) => !(b.blockerId === me && b.blockedId === otherId))
    await commit()
  },

  /** The people you blocked (never who blocked you). */
  async listBlocked() {
    const db = await getDb()
    const me = requireUserId(db)
    return db.blocks
      .filter((b) => b.blockerId === me && db.profiles.some((p) => p.id === b.blockedId))
      .map((b) => ({ person: summaryOf(db, b.blockedId), createdAt: b.createdAt }))
  },

  /** Friends' birthdays in the coming days (30 by default), soonest first. */
  async upcomingBirthdays({ days = 30 } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    return friendIdsOf(db, me)
      .map((id) => profileOf(db, id))
      .filter((p) => p.birthday)
      .map((p) => {
        const [, m, d] = p.birthday.split('-').map(Number)
        let next = new Date(today.getFullYear(), m - 1, d)
        if (next < today) next = new Date(today.getFullYear() + 1, m - 1, d)
        return {
          person: { id: p.id, firstName: p.firstName, lastName: p.lastName, avatarUrl: p.avatarUrl },
          date: toDateInput(next),
          daysLeft: Math.round((next - today) / 86_400_000),
        }
      })
      .filter((b) => b.daysLeft <= days)
      .sort((a, b) => a.daysLeft - b.daysLeft)
  },
}

