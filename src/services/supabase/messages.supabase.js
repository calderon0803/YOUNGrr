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
})

const toConversation = (json) => ({
  id: json.id,
  other: toSummary(json.other),
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

  async sendMessage(conversationId, text) {
    validate(rules.required(text, 'El mensaje'), rules.max(text, LIMITS.messageText, 'El mensaje'))
    return toMessage(await rpc('send_message', { target: conversationId, body: text }, 'No se ha podido enviar el mensaje.'))
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
