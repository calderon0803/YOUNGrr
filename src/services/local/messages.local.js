import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { areFriends, findOr404, isBlockedBetween, profileOf, summaryOf } from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { GROUP_CHAT_MAX } from '@/config/app'

// Messages for the local demo backend. Same interface as messages.supabase.js.
// A conversation is "direct" (two people) or "group" (named, up to
// GROUP_CHAT_MAX people, managed by its creator). In groups a block only hides
// the messages between those two people; in direct chats it stops the chat.

const isGroup = (conversation) => conversation.kind === 'group'

const membership = (db, me, conversationId) => {
  const conversation = findOr404(db.conversations, (c) => c.id === conversationId, 'Esta conversación no existe.')
  ensure(conversation.memberIds.includes(me), 'forbidden', 'No formas parte de esta conversación.')
  return conversation
}

const visible = (db, me, conversation) => (m) => !isGroup(conversation) || m.senderId === me || !isBlockedBetween(db, me, m.senderId)

const unreadFor = (db, me, conversation) => {
  const lastReadAt = db.conversationMembers.find((m) => m.conversationId === conversation.id && m.userId === me)?.lastReadAt
  return db.messages.filter(
    (m) => m.conversationId === conversation.id && m.senderId !== me && (!lastReadAt || m.createdAt > lastReadAt) && visible(db, me, conversation)(m),
  ).length
}

const conversationView = (db, me, conversation) => {
  const messages = db.messages.filter((m) => m.conversationId === conversation.id && visible(db, me, conversation)(m))
  const lastMessage = messages.reduce((last, m) => (!last || m.createdAt > last.createdAt ? m : last), null)
  const otherId = conversation.memberIds.find((id) => id !== me)
  return {
    id: conversation.id,
    kind: conversation.kind ?? 'direct',
    title: conversation.title ?? null,
    createdById: conversation.createdBy ?? null,
    other: isGroup(conversation) ? null : summaryOf(db, otherId),
    members: conversation.memberIds.map((id) => summaryOf(db, id)),
    lastMessage,
    unreadCount: unreadFor(db, me, conversation),
    updatedAt: conversation.updatedAt,
  }
}

const groupOfCreator = (db, me, conversationId) => {
  const conversation = membership(db, me, conversationId)
  ensure(isGroup(conversation), 'validation', 'Esta conversación no es un grupo.')
  ensure(conversation.createdBy === me, 'forbidden', 'Solo quien creó el grupo puede hacer esto.')
  return conversation
}

const validTitle = (title) => {
  const value = (title ?? '').trim()
  validate(value.length >= 1 && value.length <= LIMITS.groupChatTitle ? null : `Ponle un nombre al grupo (máximo ${LIMITS.groupChatTitle} caracteres).`)
  return value
}

/** Adds friends of `me` without a block and not already in; keeps the size limit. */
const addPeople = (db, me, conversation, people) => {
  const fresh = [...new Set(people)].filter((id) => id !== me && !conversation.memberIds.includes(id))
  for (const id of fresh) {
    ensure(areFriends(db, me, id), 'forbidden', 'Solo puedes añadir a tus amigos.')
    ensure(!isBlockedBetween(db, me, id), 'forbidden', 'No puedes añadir a esta persona.')
  }
  ensure(conversation.memberIds.length + fresh.length <= GROUP_CHAT_MAX, 'validation', `Un grupo puede tener como mucho ${GROUP_CHAT_MAX} personas.`)
  for (const id of fresh) {
    conversation.memberIds.push(id)
    db.conversationMembers.push({ conversationId: conversation.id, userId: id, lastReadAt: null })
  }
}

/** The creator's role goes to the oldest member; an empty chat goes. */
export const leaveGroupChat = (db, person, conversation) => {
  conversation.memberIds = conversation.memberIds.filter((id) => id !== person)
  db.conversationMembers = db.conversationMembers.filter((m) => !(m.conversationId === conversation.id && m.userId === person))
  if (!conversation.memberIds.length) {
    db.conversations = db.conversations.filter((c) => c.id !== conversation.id)
    db.messages = db.messages.filter((m) => m.conversationId !== conversation.id)
  } else if (conversation.createdBy === person) {
    conversation.createdBy = conversation.memberIds[0]
  }
}

export const localMessagesService = {
  /** Group chats show even before their first message; direct ones need one. */
  async listConversations() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    return db.conversations
      .filter((c) => c.memberIds.includes(me) && (isGroup(c) || db.messages.some((m) => m.conversationId === c.id)))
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
        .filter((m) => m.conversationId === conversationId && visible(db, me, conversation)(m))
        .sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
    }
  },

  /** Finds or creates the one-to-one conversation with a friend. */
  async openWith(userId) {
    await latency(60, 140)
    const db = await getDb()
    const me = requireUserId(db)
    profileOf(db, userId)
    const existing = db.conversations.find((c) => !isGroup(c) && c.memberIds.length === 2 && c.memberIds.includes(me) && c.memberIds.includes(userId))
    ensure(!isBlockedBetween(db, me, userId), 'forbidden', 'No puedes escribir a esta persona.')
    if (existing) return existing.id
    ensure(areFriends(db, me, userId), 'forbidden', 'Solo puedes escribir a tus amigos.')

    const createdAt = nowIso()
    const conversation = { id: uid('cv'), kind: 'direct', memberIds: [me, userId], createdAt, updatedAt: createdAt }
    db.conversations.push(conversation)
    db.conversationMembers.push({ conversationId: conversation.id, userId: me, lastReadAt: createdAt })
    db.conversationMembers.push({ conversationId: conversation.id, userId, lastReadAt: null })
    await commit()
    return conversation.id
  },

  /** A named chat with at least two friends; returns its id. */
  async createGroupChat(title, people) {
    const value = validTitle(title)
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(new Set(people.filter((id) => id !== me)).size >= 2, 'validation', 'Elige al menos a dos amigos para crear un grupo.')
    const createdAt = nowIso()
    const conversation = { id: uid('cv'), kind: 'group', title: value, createdBy: me, memberIds: [me], createdAt, updatedAt: createdAt }
    db.conversationMembers.push({ conversationId: conversation.id, userId: me, lastReadAt: createdAt })
    addPeople(db, me, conversation, people)
    db.conversations.push(conversation)
    await commit()
    return conversation.id
  },

  async renameGroupChat(conversationId, title) {
    const value = validTitle(title)
    await latency(60, 140)
    const db = await getDb()
    const me = requireUserId(db)
    const conversation = groupOfCreator(db, me, conversationId)
    conversation.title = value
    await commit()
    return conversationView(db, me, conversation)
  },

  async addToGroupChat(conversationId, people) {
    validate(people.length ? null : 'Elige al menos a una persona.')
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const conversation = groupOfCreator(db, me, conversationId)
    addPeople(db, me, conversation, people)
    await commit()
    return conversationView(db, me, conversation)
  },

  async removeFromGroupChat(conversationId, userId) {
    await latency(60, 140)
    const db = await getDb()
    const me = requireUserId(db)
    const conversation = groupOfCreator(db, me, conversationId)
    ensure(userId !== me, 'validation', 'Para irte, sal del grupo.')
    conversation.memberIds = conversation.memberIds.filter((id) => id !== userId)
    db.conversationMembers = db.conversationMembers.filter((m) => !(m.conversationId === conversationId && m.userId === userId))
    await commit()
    return conversationView(db, me, conversation)
  },

  async leaveGroupChat(conversationId) {
    await latency(60, 140)
    const db = await getDb()
    const me = requireUserId(db)
    const conversation = membership(db, me, conversationId)
    ensure(isGroup(conversation), 'validation', 'Esta conversación no es un grupo.')
    leaveGroupChat(db, me, conversation)
    await commit()
  },

  async sendMessage(conversationId, text) {
    validate(rules.required(text, 'El mensaje'), rules.max(text, LIMITS.messageText, 'El mensaje'))
    await latency(80, 200)
    const db = await getDb()
    const me = requireUserId(db)
    const conversation = membership(db, me, conversationId)
    // A block stops a direct chat; in a group it only hides messages.
    ensure(isGroup(conversation) || !conversation.memberIds.some((id) => id !== me && isBlockedBetween(db, me, id)), 'forbidden', 'No puedes escribir a esta persona.')
    const message = { id: uid('m'), conversationId, senderId: me, text: text.trim(), createdAt: nowIso() }
    db.messages.push(message)
    conversation.updatedAt = message.createdAt
    const self = db.conversationMembers.find((m) => m.conversationId === conversationId && m.userId === me)
    if (self) self.lastReadAt = message.createdAt
    await commit()
    return message
  },

  /** Only your own messages; the text is erased for everyone in the chat. */
  async deleteMessage(messageId) {
    await latency(80, 160)
    const db = await getDb()
    const me = requireUserId(db)
    const message = db.messages.find((m) => m.id === messageId)
    ensure(message && db.conversations.find((c) => c.id === message.conversationId)?.memberIds.includes(me), 'not_found', 'Este mensaje ya no existe.')
    ensure(message.senderId === me, 'forbidden', 'Solo puedes eliminar tus mensajes.')
    message.text = ''
    message.deleted = true
    message.deletedAt ??= nowIso()
    await commit()
    return { ...message }
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
      .reduce((sum, c) => sum + (unreadFor(db, me, c) > 0 ? 1 : 0), 0)
  },
}
