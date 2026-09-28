import { defineStore } from 'pinia'
import { reactive, ref } from 'vue'
import { postsService } from '@/services/posts.service'
import { interactionsService } from '@/services/interactions.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { GRR_TOAST_DURATION_MS } from '@/config/app'

/** @typedef {import('@/types/models').PostView} PostView */

const listState = () => {
  return { blocks: [], status: 'idle', error: null, hasMore: false, loadingMore: false, stale: false }
}

// Friends' news: one block per person, Tuenti style. Status and "ha subido N
// fotos" items are normalized in `posts` so Grr and comments update everywhere.
export const useFeedStore = defineStore('feed', () => {
  const toast = useToast()

  const posts = reactive(/** @type {Record<string, PostView>} */ ({}))
  const home = reactive(listState())
  const nearby = reactive({ ...listState(), radiusKm: null, needsLocation: false, originCity: '' })
  const grrPending = ref(new Set())

  const toBlock = ({ status, uploads, ...block }) => {
    if (status) posts[status.id] = status
    for (const upload of uploads) posts[upload.id] = upload
    return { ...block, statusId: status?.id ?? null, uploadIds: uploads.map((u) => u.id) }
  }

  const loadInto = async (state, fetchPage, { more = false } = {}) => {
    if (more) {
      if (state.loadingMore || !state.hasMore) return
      state.loadingMore = true
    } else {
      state.status = state.blocks.length && !state.stale ? state.status : 'loading'
      state.error = null
    }
    try {
      const last = more ? state.blocks[state.blocks.length - 1] : null
      const page = await fetchPage(last?.lastActivityAt ?? null)
      const blocks = page.items.map(toBlock)
      state.blocks = more ? [...state.blocks, ...blocks] : blocks
      state.hasMore = page.hasMore
      state.status = 'success'
      state.stale = false
    } catch (error) {
      if (more) toast.error(errorMessage(error))
      else {
        state.status = 'error'
        state.error = errorMessage(error)
      }
    } finally {
      state.loadingMore = false
    }
  }

  const loadActivity = (options) => loadInto(home, (before) => postsService.getActivity({ before }), options)

  const loadNearby = (radiusKm, options = {}) => {
    if (!options.more && nearby.radiusKm !== radiusKm) nearby.blocks = []
    nearby.radiusKm = radiusKm
    return loadInto(
      nearby,
      async (before) => {
        const page = await postsService.getNearbyActivity({ before, radiusKm })
        nearby.needsLocation = page.needsLocation
        nearby.originCity = page.originCity
        return page
      },
      options,
    )
  }

  /** Friendships changed: the next visit reloads. */
  const invalidate = () => {
    home.stale = true
    nearby.stale = true
  }

  /** Takes a status or album upload out of the blocks; empty blocks go away. */
  const removeEverywhere = (postId) => {
    for (const state of [home, nearby]) {
      state.blocks = state.blocks
        .map((b) => ({ ...b, statusId: b.statusId === postId ? null : b.statusId, uploadIds: b.uploadIds.filter((id) => id !== postId) }))
        .filter((b) => b.statusId || b.uploadIds.length || b.newFriends.length || b.tagged.length)
    }
    delete posts[postId]
  }

  const loadPost = async (postId) => {
    const post = await postsService.getPost(postId)
    posts[post.id] = post
    return post
  }

  /** The new status replaces the previous one. */
  const setStatus = async (text) => {
    const post = await postsService.setStatus(text)
    posts[post.id] = post
    toast.success('Estado actualizado.')
    return post
  }

  const deletePost = async (postId) => {
    try {
      await postsService.deletePost(postId)
      removeEverywhere(postId)
      toast.success('Eliminado.')
      return true
    } catch (error) {
      toast.error(errorMessage(error))
      return false
    }
  }

  const reportPost = async (postId, reason) => {
    await postsService.reportPost(postId, reason)
    removeEverywhere(postId)
    toast.success('Gracias. Lo revisaremos.')
  }

  /** Optimistic Grr toggle, with rollback if the backend fails. */
  const toggleGrr = async (postId) => {
    const post = posts[postId]
    if (!post || grrPending.value.has(postId)) return
    const next = !post.hasGrr
    const previous = { hasGrr: post.hasGrr, grrCount: post.grrCount }
    post.hasGrr = next
    post.grrCount += next ? 1 : -1
    grrPending.value.add(postId)
    try {
      const state = await interactionsService.setGrr('post', postId, next)
      Object.assign(post, state)
      toast.show(next ? 'Grr añadido.' : 'Grr eliminado.', { duration: GRR_TOAST_DURATION_MS })
    } catch (error) {
      Object.assign(post, previous)
      toast.error(errorMessage(error))
    } finally {
      grrPending.value.delete(postId)
    }
  }

  /** People who made Grr on a post or photo. */
  const loadGrrers = (targetType, targetId) => interactionsService.listGrrers(targetType, targetId)

  const loadAllComments = async (postId) => {
    const comments = await interactionsService.listComments('post', postId)
    if (posts[postId]) {
      posts[postId].comments = comments
      posts[postId].commentCount = comments.length
    }
  }

  const addComment = async (postId, text) => {
    const comment = await interactionsService.addComment('post', postId, text)
    const post = posts[postId]
    if (post) {
      post.comments = [...post.comments, comment]
      post.commentCount += 1
    }
    toast.success('Comentario publicado.')
  }

  const deleteComment = async (postId, commentId) => {
    try {
      await interactionsService.deleteComment(commentId)
      const post = posts[postId]
      if (post) {
        post.comments = post.comments.filter((c) => c.id !== commentId)
        post.commentCount -= 1
      }
      toast.success('Comentario eliminado.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return {
    posts,
    home,
    nearby,
    grrPending,
    loadActivity,
    loadNearby,
    loadPost,
    invalidate,
    setStatus,
    deletePost,
    reportPost,
    toggleGrr,
    loadGrrers,
    loadAllComments,
    addComment,
    deleteComment,
  }
})
