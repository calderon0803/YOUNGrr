import { defineStore } from 'pinia'
import { reactive, ref } from 'vue'
import { messagesService } from '@/services/messages.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { useAuthStore } from '@/stores/auth'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { BREAKPOINTS, CHAT_MAX_WINDOWS, STORAGE_KEYS } from '@/config/app'

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

  /** @param {{ markRead?: boolean }} options false for minimized chat windows */
  const loadThread = async (conversationId, { markRead = true } = {}) => {
    threads[conversationId] ??= { status: 'idle', error: null, conversation: null, messages: [] }
    const state = threads[conversationId]
    // Do not overwrite a message that is still being sent.
    if (state.messages.some((m) => m.pending)) return
    state.status = state.conversation ? 'success' : 'loading'
    state.error = null
    try {
      const result = await messagesService.getConversation(conversationId)
      state.conversation = result.conversation
      state.messages = result.messages
      state.status = 'success'
      // Polling: only write when there is something new to mark.
      if (!markRead || !result.conversation.unreadCount) return
      await messagesService.markRead(conversationId)
      state.conversation.unreadCount = 0
      const item = inbox.items.find((c) => c.id === conversationId)
      if (item) item.unreadCount = 0
      refreshUnread()
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
  }

  /** Optimistic send: the message shows at once and is marked if it fails. */
  const send = async (conversationId, text, mentions = []) => {
    const state = threads[conversationId]
    if (!state) return
    const temp = { id: uid('tmp'), conversationId, senderId: useAuthStore().meId, text: text.trim(), mentions, createdAt: nowIso(), pending: true }
    state.messages = [...state.messages, temp]
    try {
      const message = await messagesService.sendMessage(conversationId, text, mentions)
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

  const deleteMessage = async (conversationId, messageId) => {
    try {
      const deleted = await messagesService.deleteMessage(messageId)
      const state = threads[conversationId]
      if (state) state.messages = state.messages.map((m) => (m.id === messageId ? deleted : m))
      const item = inbox.items.find((c) => c.id === conversationId)
      if (item?.lastMessage?.id === messageId) item.lastMessage = deleted
    } catch (error) {
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

  // ---- Group chats ----------------------------------------------------------------
  const setConversation = (conversation) => {
    const state = threads[conversation.id]
    if (state) state.conversation = { ...state.conversation, ...conversation }
    const i = inbox.items.findIndex((c) => c.id === conversation.id)
    if (i !== -1) inbox.items[i] = { ...inbox.items[i], ...conversation }
  }

  /** Group chats you are invited to (you join only if you accept). */
  const chatInvites = reactive({ status: 'idle', error: null, items: [] })

  const loadChatInvites = async () => {
    chatInvites.status = chatInvites.status === 'success' ? 'success' : 'loading'
    try {
      chatInvites.items = await messagesService.chatInvitations()
      chatInvites.status = 'success'
    } catch (error) {
      chatInvites.status = 'error'
      chatInvites.error = errorMessage(error)
    }
  }

  const answerChatInvite = async (conversationId, accept) => {
    try {
      await messagesService.answerChatInvite(conversationId, accept)
      chatInvites.items = chatInvites.items.filter((i) => i.conversation.id !== conversationId)
      toast.success(accept ? 'Ya estás en el chat.' : 'Invitación rechazada.')
      if (accept) await loadConversations()
      return accept
    } catch (error) {
      toast.error(errorMessage(error))
      return false
    }
  }

  /** Throws on error so the dialog can show it; returns the new chat id. */
  const createGroupChat = async (title, people) => {
    const id = await messagesService.createGroupChat(title, people)
    await loadConversations()
    return id
  }

  const renameGroupChat = async (conversationId, title) => {
    setConversation(await messagesService.renameGroupChat(conversationId, title))
    toast.success('Nombre del grupo cambiado.')
  }

  const addToGroupChat = async (conversationId, people) => {
    setConversation(await messagesService.addToGroupChat(conversationId, people))
    toast.success(people.length === 1 ? 'Invitación enviada.' : 'Invitaciones enviadas.')
  }

  const removeFromGroupChat = async (conversationId, userId) => {
    try {
      setConversation(await messagesService.removeFromGroupChat(conversationId, userId))
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const leaveGroupChat = async (conversationId) => {
    try {
      await messagesService.leaveGroupChat(conversationId)
      closeWindow(conversationId)
      delete threads[conversationId]
      inbox.items = inbox.items.filter((c) => c.id !== conversationId)
      toast.success('Has salido del grupo.')
      return true
    } catch (error) {
      toast.error(errorMessage(error))
      return false
    }
  }

  // ---- Chat dock (tablet and desktop) ---------------------------------------
  // A panel at the bottom right and the open chat windows to its left,
  // nearest first. Minimized windows keep their unread messages.

  // focusId: the window the user just opened, to type in it at once.
  const dock = reactive({ open: false, windows: [], focusId: null })

  const dockKey = () => `${STORAGE_KEYS.chatDock}:${useAuthStore().meId}`

  const maxWindows = () =>
    window.matchMedia(`(min-width: ${BREAKPOINTS.desktop}px)`).matches ? CHAT_MAX_WINDOWS.desktop : CHAT_MAX_WINDOWS.tablet

  const saveDock = () => {
    try {
      localStorage.setItem(dockKey(), JSON.stringify(dock.windows))
    } catch {
      // Only a convenience.
    }
  }

  const restoreDock = () => {
    let saved = []
    try {
      saved = JSON.parse(localStorage.getItem(dockKey()) ?? '[]')
    } catch {
      saved = []
    }
    dock.windows = (Array.isArray(saved) ? saved : [])
      .filter((w) => typeof w?.id === 'string')
      .slice(0, maxWindows())
      .map((w) => ({ id: w.id, minimized: !!w.minimized }))
    dock.windows.forEach((w) => loadThread(w.id, { markRead: !w.minimized }))
  }

  const openWindow = (conversationId) => {
    dock.windows = [{ id: conversationId, minimized: false }, ...dock.windows.filter((w) => w.id !== conversationId)].slice(0, maxWindows())
    dock.focusId = conversationId
    saveDock()
    loadThread(conversationId)
  }

  const closeWindow = (conversationId) => {
    dock.windows = dock.windows.filter((w) => w.id !== conversationId)
    saveDock()
  }

  const toggleWindow = (conversationId) => {
    const win = dock.windows.find((w) => w.id === conversationId)
    if (!win) return
    win.minimized = !win.minimized
    dock.focusId = win.minimized ? null : conversationId
    saveDock()
    if (!win.minimized) loadThread(conversationId)
  }

  const toggleDock = (open = !dock.open) => {
    dock.open = open
    if (open) loadConversations()
  }

  /** New messages in the open windows (there is no push channel yet). */
  const refreshDock = () => {
    dock.windows.forEach((w) => loadThread(w.id, { markRead: !w.minimized }))
    if (dock.open) loadConversations()
  }

  return {
    inbox,
    threads,
    unreadTotal,
    loadConversations,
    refreshUnread,
    loadThread,
    send,
    discardFailed,
    deleteMessage,
    openWith,
    createGroupChat,
    chatInvites,
    loadChatInvites,
    answerChatInvite,
    renameGroupChat,
    addToGroupChat,
    removeFromGroupChat,
    leaveGroupChat,
    dock,
    restoreDock,
    openWindow,
    closeWindow,
    toggleWindow,
    toggleDock,
    refreshDock,
  }
})
