import { defineStore } from 'pinia'
import { reactive, ref } from 'vue'
import { messagesService } from '@/services/messages.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { useAuthStore } from '@/stores/auth'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'

export const useMessagesStore = defineStore('messages', () => {
  const toast = useToast()

  const inbox = reactive({ status: 'idle', error: null, items: [] })
  const threads = reactive({})
  const unreadTotal = ref(0)

  const loadConversations = async () => {
    inbox.status = inbox.status === 'success' ? 'success' : 'loading'
    inbox.error = null
    try {
      inbox.items = await messagesService.listConversations()
      inbox.status = 'success'
      unreadTotal.value = inbox.items.filter((c) => c.unreadCount > 0).length
    } catch (error) {
      inbox.status = 'error'
      inbox.error = errorMessage(error)
    }
  }

  const refreshUnread = async () => {
    try {
      unreadTotal.value = await messagesService.unreadTotal()
    } catch {
      // Badge only; ignore.
    }
  }

  const loadThread = async (conversationId) => {
    threads[conversationId] ??= { status: 'idle', error: null, conversation: null, messages: [] }
    const state = threads[conversationId]
    state.status = state.conversation ? 'success' : 'loading'
    state.error = null
    try {
      const result = await messagesService.getConversation(conversationId)
      state.conversation = result.conversation
      state.messages = result.messages
      state.status = 'success'
      await messagesService.markRead(conversationId)
      const item = inbox.items.find((c) => c.id === conversationId)
      if (item) item.unreadCount = 0
      refreshUnread()
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
  }

  /** Optimistic send: the message shows at once and is marked if it fails. */
  const send = async (conversationId, text) => {
    const state = threads[conversationId]
    if (!state) return
    const temp = { id: uid('tmp'), conversationId, senderId: useAuthStore().meId, text: text.trim(), createdAt: nowIso(), pending: true }
    state.messages = [...state.messages, temp]
    try {
      const message = await messagesService.sendMessage(conversationId, text)
      state.messages = state.messages.map((m) => (m.id === temp.id ? message : m))
      const item = inbox.items.find((c) => c.id === conversationId)
      if (item) {
        item.lastMessage = message
        item.updatedAt = message.createdAt
        inbox.items = [item, ...inbox.items.filter((c) => c.id !== conversationId)]
      }
    } catch (error) {
      state.messages = state.messages.map((m) => (m.id === temp.id ? { ...m, pending: false, failed: true } : m))
      toast.error(errorMessage(error))
    }
  }

  const discardFailed = (conversationId, messageId) => {
    const state = threads[conversationId]
    if (state) state.messages = state.messages.filter((m) => m.id !== messageId)
  }

  const openWith = async (userId) => {
    const id = await messagesService.openWith(userId)
    return id
  }

  return { inbox, threads, unreadTotal, loadConversations, refreshUnread, loadThread, send, discardFailed, openWith }
})
