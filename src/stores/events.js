import { defineStore } from 'pinia'
import { computed, reactive } from 'vue'
import { eventsService } from '@/services/events.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { plural } from '@/utils/text'

const RSVP_FEEDBACK = {
  going: 'Has confirmado que asistirás.',
  maybe: 'Respuesta guardada: quizás.',
  declined: 'Has indicado que no asistirás.',
}

export const useEventsStore = defineStore('events', () => {
  const toast = useToast()

  const events = reactive({})
  const overview = reactive({ status: 'idle', error: null, invitations: [], upcoming: [], past: [] })
  const details = reactive({})

  const pendingCount = computed(() => overview.invitations.length)

  const keep = (list) => {
    for (const e of list) events[e.id] = e
    return list.map((e) => e.id)
  }

  const loadEvents = async () => {
    overview.status = overview.status === 'success' ? 'success' : 'loading'
    overview.error = null
    try {
      const result = await eventsService.listEvents()
      overview.invitations = keep(result.invitations)
      overview.upcoming = keep(result.upcoming)
      overview.past = keep(result.past)
      overview.status = 'success'
    } catch (error) {
      overview.status = 'error'
      overview.error = errorMessage(error)
    }
  }

  const loadEvent = async (eventId) => {
    details[eventId] ??= { status: 'idle', error: null }
    const state = details[eventId]
    state.status = events[eventId] ? 'success' : 'loading'
    state.error = null
    try {
      events[eventId] = await eventsService.getEvent(eventId)
      state.status = 'success'
    } catch (error) {
      state.status = 'error'
      state.error = errorMessage(error)
    }
  }

  const createEvent = async (input, inviteeIds) => {
    const event = await eventsService.createEvent(input, inviteeIds)
    events[event.id] = event
    overview.upcoming = [event.id, ...overview.upcoming]
    toast.success('Evento creado.')
    return event
  }

  const updateEvent = async (eventId, input) => {
    events[eventId] = await eventsService.updateEvent(eventId, input)
    toast.success('Evento actualizado.')
  }

  const deleteEvent = async (eventId) => {
    await eventsService.deleteEvent(eventId)
    for (const key of ['invitations', 'upcoming', 'past']) overview[key] = overview[key].filter((id) => id !== eventId)
    delete events[eventId]
    toast.success('Evento eliminado.')
  }

  const invite = async (eventId, userIds) => {
    const { event, invited } = await eventsService.invite(eventId, userIds)
    events[eventId] = event
    toast.success(invited ? `${plural(invited, 'invitación enviada', 'invitaciones enviadas')}.` : 'Ya estaban invitados.')
  }

  const respond = async (eventId, status) => {
    try {
      events[eventId] = await eventsService.respond(eventId, status)
      if (overview.invitations.includes(eventId)) {
        overview.invitations = overview.invitations.filter((id) => id !== eventId)
        overview.upcoming = [...overview.upcoming, eventId]
      }
      toast.success(RSVP_FEEDBACK[status])
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return { events, overview, details, pendingCount, loadEvents, loadEvent, createEvent, updateEvent, deleteEvent, invite, respond }
})
