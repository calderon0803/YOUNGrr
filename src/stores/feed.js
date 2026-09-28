import { defineStore } from 'pinia'
import { reactive, ref } from 'vue'
import { postsService } from '@/services/posts.service'
import { interactionsService } from '@/services/interactions.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { GRR_TOAST_DURATION_MS } from '@/config/app'

/** @typedef {import('@/types/models').PostView} PostView */

const listState = () => {
  return { ids: [], status: 'idle', error: null, hasMore: false, loadingMore: false, stale: false }
}

export const useFeedStore = defineStore('feed', () => {
  const toast = useToast()

  /** Normalized posts: home feed and profile timelines share the same objects. */
  const posts = reactive(/** @type {Record<string, PostView>} */ ({}))
  const home = reactive(listState())
  /** "Cerca de ti": distance per post lives here, not on the shared post objects. */
  const nearby = reactive({ ...listState(), radiusKm: null, needsLocation: false, originCity: '', meta: {} })
  const timelines = reactive(/** @type {Record<string, ReturnType<typeof listState>>} */ ({}))
  const grrPending = ref(new Set())

  const store = (items) => {
    for (const post of items) posts[post.id] = post
    return items.map((p) => p.id)
  }

  const removeEverywhere = (postId) => {
    home.ids = home.ids.filter((id) => id !== postId)
    nearby.ids = nearby.ids.filter((id) => id !== postId)
    for (const t of Object.values(timelines)) t.ids = t.ids.filter((id) => id !== postId)
    delete posts[postId]
  }

  const loadInto = async (state, fetchPage, { more = false } = {}) => {
    if (more) {
      if (state.loadingMore || !state.hasMore) return
      state.loadingMore = true
    } else {
      state.status = state.ids.length && !state.stale ? state.status : 'loading'
      state.error = null
    }
    try {
      const last = more ? posts[state.ids[state.ids.length - 1]] : null
      const page = await fetchPage(last?.createdAt ?? null)
      const ids = store(page.items)
      state.ids = more ? [...state.ids, ...ids] : ids
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

  const loadFeed = (options) => loadInto(home, (before) => postsService.getFeed({ before }), options)

  const loadTimeline = (userId, options) => {
    timelines[userId] ??= listState()
    return loadInto(timelines[userId], (before) => postsService.getUserPosts(userId, { before }), options)
  }

  /** Friendships changed: the next visit reloads. */
  const loadNearby = (radiusKm, options = {}) => {
    if (!options.more && nearby.radiusKm !== radiusKm) {
      nearby.ids = []
      nearby.meta = {}
    }
    nearby.radiusKm = radiusKm
    return loadInto(
      nearby,
      async (before) => {
        const page = await postsService.getNearbyFeed({ before, radiusKm })
        nearby.needsLocation = page.needsLocation
        nearby.originCity = page.originCity
        const items = page.items.map(({ nearby: info, ...post }) => {
          if (info) nearby.meta[post.id] = info
          return post
        })
        return { ...page, items }
      },
      options,
    )
  }

  const invalidate = () => {
    home.stale = true
    nearby.stale = true
    for (const t of Object.values(timelines)) t.stale = true
  }

  const loadPost = async (postId) => {
    const post = await postsService.getPost(postId)
    posts[post.id] = post
    return post
  }

  const createPost = async (input) => {
    const post = await postsService.createPost(input)
    posts[post.id] = post
    home.ids = [post.id, ...home.ids]
    const own = timelines[post.authorId]
    if (own) own.ids = [post.id, ...own.ids]
    toast.success('Publicación publicada.')
    return post
  }

  const updatePost = async (postId, text) => {
    const updated = await postsService.updatePost(postId, text)
    posts[postId] = { ...updated, comments: posts[postId]?.comments ?? updated.comments }
    toast.success('Publicación actualizada.')
  }

  const deletePost = async (postId) => {
    try {
      await postsService.deletePost(postId)
      removeEverywhere(postId)
      toast.success('Publicación eliminada.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const hidePost = async (postId) => {
    const index = home.ids.indexOf(postId)
    const nearbyIndex = nearby.ids.indexOf(postId)
    home.ids = home.ids.filter((id) => id !== postId)
    nearby.ids = nearby.ids.filter((id) => id !== postId)
    try {
      await postsService.hidePost(postId)
      toast.show('Publicación ocultada.', {
        action: {
          label: 'Deshacer',
          run: async () => {
            await postsService.unhidePost(postId)
            if (index !== -1 && !home.ids.includes(postId)) home.ids.splice(index, 0, postId)
            if (nearbyIndex !== -1 && !nearby.ids.includes(postId)) nearby.ids.splice(nearbyIndex, 0, postId)
          },
        },
      })
    } catch (error) {
      if (index !== -1) home.ids.splice(index, 0, postId)
      if (nearbyIndex !== -1) nearby.ids.splice(nearbyIndex, 0, postId)
      toast.error(errorMessage(error))
    }
  }

  const reportPost = async (postId, reason) => {
    await postsService.reportPost(postId, reason)
    home.ids = home.ids.filter((id) => id !== postId)
    nearby.ids = nearby.ids.filter((id) => id !== postId)
    toast.success('Gracias. Revisaremos la publicación.')
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
    timelines,
    grrPending,
    loadFeed,
    loadNearby,
    loadTimeline,
    loadPost,
    invalidate,
    createPost,
    updatePost,
    deletePost,
    hidePost,
    reportPost,
    toggleGrr,
    loadGrrers,
    loadAllComments,
    addComment,
    deleteComment,
  }
})
