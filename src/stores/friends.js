import { defineStore } from 'pinia'
import { computed, reactive } from 'vue'
import { friendsService } from '@/services/friends.service'
import { usersService } from '@/services/users.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { useFeedStore } from '@/stores/feed'
import { useUserStore } from '@/stores/user'
import { useAuthStore } from '@/stores/auth'
import { fullName } from '@/utils/text'

export const useFriendsStore = defineStore('friends', () => {
  const toast = useToast()

  /** Friend lists by user id. */
  const lists = reactive({})
  const requests = reactive({ status: 'idle', error: null, incoming: [], outgoing: [] })
  const suggestions = reactive({ status: 'idle', items: [] })
  const birthdays = reactive({ status: 'idle', items: [] })
  const people = reactive({ query: '', status: 'idle', error: null, items: [] })
  let peopleSeq = 0
  /** Person ids with an action in flight, to disable their buttons. */
  const busy = reactive(new Set())

  const incomingCount = computed(() => requests.incoming.length)

  const loadFriends = async (userId) => {
    lists[userId] ??= { status: 'idle', error: null, items: [] }
    const state = lists[userId]
    state.status = state.items.length ? state.status : 'loading'
    state.error = null
    try {
      state.items = await friendsService.listFriends(userId)
      state.status = 'success'
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
  }

  const loadRequests = async () => {
    requests.status = requests.status === 'success' ? 'success' : 'loading'
    requests.error = null
    try {
      Object.assign(requests, await friendsService.listRequests(), { status: 'success' })
    } catch (error) {
      requests.status = 'error'
      requests.error = errorMessage(error)
    }
  }

  const loadSuggestions = async () => {
    suggestions.status = 'loading'
    try {
      suggestions.items = await usersService.suggestions()
      suggestions.status = 'success'
    } catch {
      suggestions.status = 'error'
    }
  }

  const loadBirthdays = async () => {
    birthdays.status = 'loading'
    try {
      birthdays.items = await friendsService.upcomingBirthdays()
      birthdays.status = 'success'
    } catch {
      birthdays.status = 'error'
    }
  }

  const searchPeople = async (query) => {
    people.query = query
    if (!query.trim()) {
      Object.assign(people, { status: 'idle', items: [], error: null })
      return
    }
    const seq = ++peopleSeq
    people.status = 'loading'
    people.error = null
    try {
      const items = await usersService.searchPeople(query)
      if (seq === peopleSeq) Object.assign(people, { items, status: 'success' })
    } catch (error) {
      if (seq === peopleSeq) Object.assign(people, { status: 'error', error: errorMessage(error) })
    }
  }

  /** Propagates a new friendship status to every cached list and profile. */
  const sync = (person) => {
    const me = useAuthStore().meId
    for (const state of Object.values(lists)) {
      state.items = state.items.map((p) => (p.id === person.id ? { ...p, ...person } : p))
    }
    const myList = me ? lists[me] : null
    if (myList && person.friendship !== 'friends') myList.items = myList.items.filter((p) => p.id !== person.id)
    if (myList && person.friendship === 'friends' && !myList.items.some((p) => p.id === person.id)) {
      myList.items = [...myList.items, person].sort((a, b) => a.firstName.localeCompare(b.firstName, 'es'))
    }
    suggestions.items = suggestions.items.map((p) => (p.id === person.id ? person : p))
    people.items = people.items.map((p) => (p.id === person.id ? person : p))
    requests.incoming = requests.incoming.filter((r) => !(r.person.id === person.id && person.friendship !== 'request_received'))
    requests.outgoing = requests.outgoing.filter((r) => !(r.person.id === person.id && person.friendship !== 'request_sent'))

    const users = useUserStore()
    if (users.profiles[person.id]) users.loadProfile(person.id, { silent: true })
    if (me && users.profiles[me]) users.loadProfile(me, { silent: true })
  }

  const run = async (personId, action, message) => {
    if (busy.has(personId)) return null
    busy.add(personId)
    try {
      const person = await action(personId)
      sync(person)
      toast.success(message(person))
      return person
    } catch (error) {
      toast.error(errorMessage(error))
      return null
    } finally {
      busy.delete(personId)
    }
  }

  const send = (id) =>
    run(id, (x) => friendsService.sendRequest(x), (p) => (p.friendship === 'friends' ? 'Ahora sois amigos.' : 'Solicitud enviada.'))

  const cancel = (id) => run(id, (x) => friendsService.cancelRequest(x), () => 'Solicitud cancelada.')

  const accept = async (id) => {
    const person = await run(id, (x) => friendsService.acceptRequest(x), () => 'Ahora sois amigos.')
    if (person) useFeedStore().invalidate()
    return person
  }

  const reject = (id) => run(id, (x) => friendsService.rejectRequest(x), () => 'Solicitud rechazada.')

  const remove = async (id) => {
    const person = await run(id, (x) => friendsService.removeFriend(x), (p) => `${fullName(p)} ya no está en tus amigos.`)
    if (person) useFeedStore().invalidate()
    return person
  }

  return {
    lists,
    requests,
    suggestions,
    birthdays,
    people,
    busy,
    incomingCount,
    loadFriends,
    loadRequests,
    loadSuggestions,
    loadBirthdays,
    searchPeople,
    send,
    cancel,
    accept,
    reject,
    remove,
  }
})
