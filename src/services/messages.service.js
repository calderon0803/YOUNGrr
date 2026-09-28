import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { areFriends, findOr404, profileOf, summaryOf } from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'

const membership = (db, me, conversationId) => {
  const conversation = findOr404(db.conversations, (c) => c.id === conversationId, 'Esta conversación no existe.')
  ensure(conversation.memberIds.includes(me), 'forbidden', 'No formas parte de esta conversación.')
  return conversation
}

const unreadFor = (db, me, conversationId) => {
  const lastReadAt = db.conversationMembers.find((m) => m.conversationId === conversationId && m.userId === me)?.lastReadAt
  return db.messages.filter(
    (m) => m.conversationId === conversationId && m.senderId !== me && (!lastReadAt || m.createdAt > lastReadAt),
  ).length
}

const conversationView = (db, me, conversation) => {
  const otherId = conversation.memberIds.find((id) => id !== me)
  const messages = db.messages.filter((m) => m.conversationId === conversation.id)
  const lastMessage = messages.reduce((last, m) => (!last || m.createdAt > last.createdAt ? m : last), null)
  return {
    id: conversation.id,
    other: summaryOf(db, otherId),
    lastMessage,
    unreadCount: unreadFor(db, me, conversation.id),
    updatedAt: conversation.updatedAt,
  }
}

export const messagesService = {
  async listConversations() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    return db.conversations
      .filter((c) => c.memberIds.includes(me) && db.messages.some((m) => m.conversationId === c.id))
      .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
      .map((c) => conversationView(db, me, c))
  },

  async getConversation(conversationId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const conversation = membership(db, me, conversationId)
    return {
      conversation: conversationView(db, me, conversation),
      messages: db.messages
        .filter((m) => m.conversationId === conversationId)
        .sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
    }
  },

  /** Finds or creates the one-to-one conversation with a friend. */
  async openWith(userId) {
    await latency(60, 140)
    const db = await getDb()
    const me = requireUserId(db)
    profileOf(db, userId)
    const existing = db.conversations.find(
      (c) => c.memberIds.length === 2 && c.memberIds.includes(me) && c.memberIds.includes(userId),
    )
    if (existing) return existing.id
    ensure(areFriends(db, me, userId), 'forbidden', 'Solo puedes escribir a tus amigos.')

    const createdAt = nowIso()
    const conversation = { id: uid('cv'), memberIds: [me, userId], createdAt, updatedAt: createdAt }
    db.conversations.push(conversation)
    db.conversationMembers.push({ conversationId: conversation.id, userId: me, lastReadAt: createdAt })
    db.conversationMembers.push({ conversationId: conversation.id, userId, lastReadAt: null })
    await commit()
    return conversation.id
  },

  async sendMessage(conversationId, text) {
    validate(rules.required(text, 'El mensaje'), rules.max(text, LIMITS.messageText, 'El mensaje'))
    await latency(80, 200)
    const db = await getDb()
    const me = requireUserId(db)
    const conversation = membership(db, me, conversationId)
    const message = { id: uid('m'), conversationId, senderId: me, text: text.trim(), createdAt: nowIso() }
    db.messages.push(message)
    conversation.updatedAt = message.createdAt
    const self = db.conversationMembers.find((m) => m.conversationId === conversationId && m.userId === me)
    if (self) self.lastReadAt = message.createdAt
    await commit()
    return message
  },

  async markRead(conversationId) {
    const db = await getDb()
    const me = requireUserId(db)
    membership(db, me, conversationId)
    const member = db.conversationMembers.find((m) => m.conversationId === conversationId && m.userId === me)
    if (member) member.lastReadAt = nowIso()
    await commit()
  },

  async unreadTotal() {
    const db = await getDb()
    const me = requireUserId(db)
    return db.conversations
      .filter((c) => c.memberIds.includes(me))
      .reduce((sum, c) => sum + (unreadFor(db, me, c.id) > 0 ? 1 : 0), 0)
  },
}
