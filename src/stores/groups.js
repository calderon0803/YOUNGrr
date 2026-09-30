import { defineStore } from 'pinia'
import { reactive } from 'vue'
import { groupsService } from '@/services/groups.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { useNotificationsStore } from '@/stores/notifications'
import { plural } from '@/utils/text'

/** Groups, your invitations and each group's Gallinero. */
export const useGroupsStore = defineStore('groups', () => {
  const toast = useToast()
  const notifications = useNotificationsStore()

  const groups = reactive({})
  const posts = reactive({})
  const mine = reactive({ status: 'idle', error: null, ids: [] })
  const invitations = reactive({ status: 'idle', error: null, ids: [] })
  const notices = reactive({ status: 'idle', error: null, items: [] })
  const found = reactive({ status: 'idle', error: null, query: '', ids: [] })
  /** Per group: { status, error, members, requests }. */
  const details = reactive({})
  /** Per group: { status, error, ids, hasMore, loadingMore }. */
  const boards = reactive({})

  const keep = (list) => {
    for (const g of list) groups[g.id] = g
    return list.map((g) => g.id)
  }

  const load = async (state, action) => {
    state.status = state.status === 'success' ? 'success' : 'loading'
    state.error = null
    try {
      await action()
      state.status = 'success'
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
  }

  const loadMine = () => load(mine, async () => (mine.ids = keep(await groupsService.listMine())))
  const loadInvitations = () => load(invitations, async () => (invitations.ids = keep(await groupsService.invitations())))
  const loadNotices = () => load(notices, async () => (notices.items = await groupsService.notices()))

  const search = async (query) => {
    found.query = query
    if (!query.trim()) {
      found.ids = []
      found.status = 'idle'
      return
    }
    found.status = 'loading'
    found.error = null
    try {
      const result = await groupsService.search(query)
      if (found.query === query) {
        found.ids = keep(result)
        found.status = 'success'
      }
    } catch (error) {
      found.status = 'error'
      found.error = errorMessage(error)
    }
  }

  const loadGroup = (groupId) => {
    details[groupId] ??= { status: 'idle', error: null, members: [], requests: [] }
    const state = details[groupId]
    if (groups[groupId] && state.status !== 'success') state.status = 'success'
    return load(state, async () => {
      const data = await groupsService.getGroup(groupId)
      groups[groupId] = data.group
      state.members = data.members
      state.requests = data.requests
    })
  }

  /** Something changed: reload the group and the lists it is in. */
  const refresh = (groupId) => {
    if (details[groupId]) loadGroup(groupId)
    if (mine.status === 'success') loadMine()
    notifications.loadSummary()
  }

  const dropFromLists = (groupId) => {
    mine.ids = mine.ids.filter((id) => id !== groupId)
    invitations.ids = invitations.ids.filter((id) => id !== groupId)
    found.ids = found.ids.filter((id) => id !== groupId)
  }

  const createGroup = async (input) => {
    const group = await groupsService.createGroup(input)
    groups[group.id] = group
    mine.ids = [group.id, ...mine.ids]
    toast.success('Grupo creado.')
    return group
  }

  const updateGroup = async (groupId, input) => {
    groups[groupId] = await groupsService.updateGroup(groupId, input)
    toast.success('Grupo actualizado.')
  }

  const deleteGroup = async (groupId) => {
    await groupsService.deleteGroup(groupId)
    dropFromLists(groupId)
    delete groups[groupId]
    delete details[groupId]
    delete boards[groupId]
    toast.success('Grupo eliminado.')
  }

  const invite = async (groupId, userIds) => {
    const invited = await groupsService.invite(groupId, userIds)
    toast.success(invited ? `${plural(invited, 'invitación enviada', 'invitaciones enviadas')}.` : 'Ya estaban invitados o en el grupo.')
    refresh(groupId)
  }

  const answerInvite = async (groupId, accept) => {
    try {
      const group = await groupsService.answerInvite(groupId, accept)
      invitations.ids = invitations.ids.filter((id) => id !== groupId)
      if (group) {
        groups[groupId] = group
        mine.ids = [groupId, ...mine.ids.filter((id) => id !== groupId)]
      }
      toast.success(accept ? 'Ya formas parte del grupo.' : 'Invitación rechazada.')
      refresh(groupId)
      return !!group
    } catch (error) {
      toast.error(errorMessage(error))
      return false
    }
  }

  const requestToJoin = async (groupId) => {
    try {
      groups[groupId] = await groupsService.requestToJoin(groupId)
      toast.success(groups[groupId].myRole ? 'Ya formas parte del grupo.' : 'Solicitud enviada. Te avisarán cuando la acepten.')
      if (groups[groupId].myRole) refresh(groupId)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const cancelRequest = async (groupId) => {
    try {
      const group = await groupsService.cancelRequest(groupId)
      if (group) groups[groupId] = group
      toast.success('Solicitud retirada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const answerRequest = async (groupId, userId, accept) => {
    try {
      await groupsService.answerRequest(groupId, userId, accept)
      toast.success(accept ? 'Solicitud aceptada.' : 'Solicitud rechazada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
    refresh(groupId)
  }

  const leave = async (groupId) => {
    try {
      await groupsService.leave(groupId)
      dropFromLists(groupId)
      delete boards[groupId]
      delete details[groupId]
      toast.success('Has salido del grupo.')
      return true
    } catch (error) {
      toast.error(errorMessage(error))
      return false
    }
  }

  const removeMember = async (groupId, userId) => {
    try {
      await groupsService.removeMember(groupId, userId)
      toast.success('Se ha quitado del grupo.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
    refresh(groupId)
  }

  const setRole = async (groupId, userId, role) => {
    try {
      await groupsService.setRole(groupId, userId, role)
      toast.success(role === 'owner' ? 'Has pasado el grupo a otra persona.' : 'Papel cambiado.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
    refresh(groupId)
  }

  /** Visiting the Gallinero: its posts stop being new. */
  const markSeen = async (groupId) => {
    try {
      await groupsService.markSeen(groupId)
      if (groups[groupId]) groups[groupId] = { ...groups[groupId], newPosts: 0 }
    } catch {
      // Counters only.
    }
  }

  const dismissNotice = async (noticeId) => {
    notices.items = notices.items.filter((n) => n.id !== noticeId)
    try {
      await groupsService.dismissNotice(noticeId)
      notifications.loadSummary()
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  // ---- The Gallinero --------------------------------------------------------------------------

  const keepPosts = (list) => {
    for (const p of list) posts[p.id] = p
    return list.map((p) => p.id)
  }

  const loadPosts = async (groupId, { more = false } = {}) => {
    boards[groupId] ??= { status: 'idle', error: null, ids: [], hasMore: false, loadingMore: false }
    const board = boards[groupId]
    if (more) {
      if (board.loadingMore || !board.hasMore) return
      board.loadingMore = true
    } else {
      board.status = board.status === 'success' ? 'success' : 'loading'
    }
    board.error = null
    try {
      const before = more ? posts[board.ids.at(-1)]?.createdAt : null
      const page = await groupsService.listPosts(groupId, { before })
      const ids = keepPosts(page.items)
      board.ids = more ? [...board.ids, ...ids] : ids
      board.hasMore = page.hasMore
      board.status = 'success'
    } catch (error) {
      if (more) toast.error(errorMessage(error))
      else {
        board.status = 'error'
        board.error = errorMessage(error)
      }
    } finally {
      board.loadingMore = false
    }
  }

  const createPost = async (groupId, input) => {
    const post = await groupsService.createPost(groupId, input)
    posts[post.id] = post
    if (boards[groupId]) boards[groupId].ids = [post.id, ...boards[groupId].ids]
    return post
  }

  const deletePost = async (postId) => {
    const groupId = posts[postId]?.groupId
    try {
      await groupsService.deletePost(postId)
      if (boards[groupId]) boards[groupId].ids = boards[groupId].ids.filter((id) => id !== postId)
      delete posts[postId]
      toast.success('Publicación eliminada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const reply = async (postId, text) => {
    posts[postId] = await groupsService.reply(postId, text)
  }

  const deleteReply = async (postId, replyId) => {
    try {
      posts[postId] = await groupsService.deleteReply(replyId)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const toggleGrr = async (postId) => {
    const post = posts[postId]
    if (!post) return
    try {
      posts[postId] = await groupsService.setGrr(postId, !post.hasGrr)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return {
    groups,
    posts,
    mine,
    invitations,
    notices,
    found,
    details,
    boards,
    loadMine,
    loadInvitations,
    loadNotices,
    search,
    loadGroup,
    createGroup,
    updateGroup,
    deleteGroup,
    invite,
    answerInvite,
    requestToJoin,
    cancelRequest,
    answerRequest,
    leave,
    removeMember,
    setRole,
    markSeen,
    dismissNotice,
    loadPosts,
    createPost,
    deletePost,
    reply,
    deleteReply,
    toggleGrr,
  }
})
