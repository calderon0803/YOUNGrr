// Profile wall ("tablón") for the local demo backend. Same interface as wall.supabase.js.
// Whoever can see the profile reads it; the owner and their friends write on it;
// the author or the profile owner delete a message.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { areFriends, canViewProfile, findOr404, profileOf, summaryOf } from '@/services/local/access'
import { dropNotifications, notify } from '@/services/local/notify'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'

const messageView = (db, m) => ({ ...m, author: summaryOf(db, m.authorId) })

export const localWallService = {
  async listWall(profileId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    profileOf(db, profileId)
    ensure(canViewProfile(db, me, profileId), 'forbidden', 'Este perfil es privado.')
    return {
      messages: db.wallMessages
        .filter((m) => m.profileId === profileId)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
        .map((m) => messageView(db, m)),
      canWrite: profileId === me || areFriends(db, me, profileId),
    }
  },

  async addWallMessage(profileId, text) {
    validate(rules.required(text, 'El mensaje'), rules.max(text, LIMITS.wallText, 'El mensaje'))
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    profileOf(db, profileId)
    ensure(profileId === me || areFriends(db, me, profileId), 'forbidden', 'Solo sus amigos pueden escribir en su tablón.')
    const message = { id: uid('w'), profileId, authorId: me, text: text.trim(), createdAt: nowIso() }
    db.wallMessages.push(message)
    notify(db, { userId: profileId, actorId: me, type: 'wall_message', targetId: profileId })
    await commit()
    return messageView(db, message)
  },

  async deleteWallMessage(messageId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const message = findOr404(db.wallMessages, (m) => m.id === messageId, 'Este mensaje ya no existe.')
    ensure(message.authorId === me || message.profileId === me, 'forbidden', 'No puedes borrar este mensaje.')
    db.wallMessages = db.wallMessages.filter((m) => m.id !== messageId)
    const stillThere = db.wallMessages.some((m) => m.profileId === message.profileId && m.authorId === message.authorId)
    if (!stillThere) {
      dropNotifications(db, (n) => n.type === 'wall_message' && n.userId === message.profileId && n.actorId === message.authorId)
    }
    await commit()
  },
}
