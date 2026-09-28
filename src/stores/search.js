import { defineStore } from 'pinia'
import { reactive } from 'vue'
import { searchService } from '@/services/search.service'
import { errorMessage } from '@/services/errors'

export const useSearchStore = defineStore('search', () => {
  const state = reactive({ query: '', status: 'idle', error: null, people: [], events: [], albums: [] })
  let requestSeq = 0

  const search = async (query) => {
    state.query = query
    if (!query.trim()) {
      Object.assign(state, { status: 'idle', people: [], events: [], albums: [] })
      return
    }
    const seq = ++requestSeq
    state.status = 'loading'
    state.error = null
    try {
      const results = await searchService.search(query)
      // Ignore answers to older queries.
      if (seq === requestSeq) Object.assign(state, results, { status: 'success' })
    } catch (error) {
      if (seq === requestSeq) Object.assign(state, { status: 'error', error: errorMessage(error) })
    }
  }

  return { state, search }
})
