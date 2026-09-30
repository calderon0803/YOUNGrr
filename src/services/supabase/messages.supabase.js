// Private messages with Supabase. Same interface as local/messages.local.js.
import { rpc } from '@/services/supabase/client'
import { toSummary } from '@/services/supabase/mappers'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'

const toMessage = (json) => ({
  id: json.id,
  conversationId: json.conversation_id,
  senderId: json.sender_id,
  text: json.text,
  createdAt: json.created_at,
  // Deleted by its sender: the text is gone for both people.
  deleted: !!json.deleted,
  // Ids of the people mentioned (group chats).
  mentions: json.mentions ?? [],
})

const toConversation = (json) => ({
  id: json.id,
  // "direct" (two people) or "group" (named, managed by its creator).
  kind: json.kind ?? 'direct',
  title: json.title ?? null,
  createdById: json.created_by ?? null,
  other: json.other ? toSummary(json.other) : null,
  members: (json.members ?? []).map(toSummary),
  // Invited to a group chat, not answered yet.
  invited: (json.invited ?? []).map(toSummary),
  lastMessage: json.last_message ? toMessage(json.last_message) : null,
  unreadCount: json.unread_count,
  updatedAt: json.updated_at,
})

export const supabaseMessagesService = {
  async listConversations() {
    return (await rpc('list_conversations', {}, 'No se han podido cargar tus mensajes.')).map(toConversation)
  },

  async getConversation(conversationId) {
    const data = await rpc('get_conversation', { target: conversationId }, 'No se ha podido cargar la conversación.')
    return { conversation: toConversation(data.conversation), messages: data.messages.map(toMessage) }
  },

  /** Finds or creates the one-to-one conversation with a friend. */
  async openWith(userId) {
    return rpc('start_conversation', { other: userId }, 'No se ha podido abrir la conversación.')
  },

  /** A named chat with at least two friends; returns its id. */
  async createGroupChat(title, people) {
    validate(rules.required(title, 'El nombre del grupo'), rules.max(title, LIMITS.groupChatTitle, 'El nombre del grupo'))
    return rpc('create_group_chat', { title, people }, 'No se ha podido crear el grupo.')
  },

  async renameGroupChat(conversationId, title) {
    validate(rules.required(title, 'El nombre del grupo'), rules.max(title, LIMITS.groupChatTitle, 'El nombre del grupo'))
    return toConversation(await rpc('rename_group_chat', { target: conversationId, title }, 'No se ha podido cambiar el nombre.'))
  },

  async addToGroupChat(conversationId, people) {
    return toConversation(await rpc('add_to_group_chat', { target: conversationId, people }, 'No se han podido añadir.'))
  },

  async removeFromGroupChat(conversationId, userId) {
    return toConversation(await rpc('remove_from_group_chat', { target: conversationId, person: userId }, 'No se ha podido quitar del grupo.'))
  },

  async leaveGroupChat(conversationId) {
    await rpc('leave_group_chat', { target: conversationId }, 'No se ha podido salir del grupo.')
  },

  async sendMessage(conversationId, text, mentions = []) {
    validate(rules.required(text, 'El mensaje'), rules.max(text, LIMITS.messageText, 'El mensaje'))
    return toMessage(await rpc('send_message', { target: conversationId, body: text, mentions }, 'No se ha podido enviar el mensaje.'))
  },

  /** Group chats you are invited to: you join only if you accept. */
  async chatInvitations() {
    return (await rpc('chat_invitations', {}, 'No se han podido cargar tus invitaciones.')).map((i) => ({
      conversation: toConversation(i.conversation),
      invitedBy: i.invited_by ? toSummary(i.invited_by) : null,
      createdAt: i.created_at,
    }))
  },

  async answerChatInvite(conversationId, accept) {
    const data = await rpc('answer_chat_invite', { target: conversationId, accept }, 'No se ha podido guardar tu respuesta.')
    return data ? toConversation(data) : null
  },

  /** Only your own messages; the text is erased for both people. */
  async deleteMessage(messageId) {
    return toMessage(await rpc('delete_message', { target: messageId }, 'No se ha podido eliminar el mensaje.'))
  },

  async markRead(conversationId) {
    await rpc('mark_conversation_read', { target: conversationId }, 'No se ha podido actualizar la conversación.')
  },

  async unreadTotal() {
    return rpc('unread_conversations', {}, 'No se han podido contar tus mensajes.')
  },
}
