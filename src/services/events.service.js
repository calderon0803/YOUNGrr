import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { areFriends, findOr404 } from '@/services/local/access'
import { dropNotifications } from '@/services/local/notify'
import { canSeeEvent, eventView } from '@/services/local/views'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { eventDateTime, isPastEvent, nowIso } from '@/utils/time'

const RSVP = ['going', 'maybe', 'declined', 'pending']

const validateEvent = (input) => {
  validate(
    rules.required(input.title, 'El título'),
    rules.max(input.title, LIMITS.eventTitle, 'El título'),
    rules.max(input.description, LIMITS.eventDescription, 'La descripción'),
    rules.date(input.date),
    rules.time(input.time),
    rules.required(input.location, 'La ubicación'),
    rules.max(input.location, LIMITS.eventLocation, 'La ubicación'),
  )
}

const visibleEvent = (db, me, eventId) => {
  const event = findOr404(db.events, (e) => e.id === eventId, 'Este evento ya no existe.')
  ensure(canSeeEvent(db, me, event), 'forbidden', 'No estás invitado a este evento.')
  return event
}

const inviteMany = (db, me, event, userIds) => {
  const already = new Set(db.eventMembers.filter((m) => m.eventId === event.id).map((m) => m.userId))
  const fresh = [...new Set(userIds)].filter((id) => !already.has(id))
  fresh.forEach((id) => ensure(areFriends(db, me, id), 'forbidden', 'Solo puedes invitar a tus amigos.'))
  for (const userId of fresh) {
    db.eventMembers.push({ eventId: event.id, userId, status: 'pending', invitedBy: me, respondedAt: null })
  }
  return fresh.length
}

export const eventsService = {
  async listEvents() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const mine = db.events.filter((e) => canSeeEvent(db, me, e)).map((e) => eventView(db, me, e))
    const when = (e) => eventDateTime(e.date, e.time).getTime()
    const upcoming = mine.filter((e) => !isPastEvent(e.date, e.time)).sort((a, b) => when(a) - when(b))
    return {
      invitations: upcoming.filter((e) => e.myStatus === 'pending'),
      upcoming: upcoming.filter((e) => e.myStatus !== 'pending'),
      past: mine.filter((e) => isPastEvent(e.date, e.time)).sort((a, b) => when(b) - when(a)),
    }
  },

  async getEvent(eventId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    return eventView(db, me, visibleEvent(db, me, eventId))
  },

  async createEvent(input, inviteeIds = []) {
    validateEvent(input)
    await latency(200, 400)
    const db = await getDb()
    const me = requireUserId(db)
    const createdAt = nowIso()
    const event = {
      id: uid('e'),
      creatorId: me,
      title: input.title.trim(),
      description: input.description.trim(),
      imageUrl: input.imageUrl,
      date: input.date,
      time: input.time,
      location: input.location.trim(),
      createdAt,
      updatedAt: createdAt,
    }
    db.events.push(event)
    db.eventMembers.push({ eventId: event.id, userId: me, status: 'going', invitedBy: me, respondedAt: createdAt })
    inviteMany(db, me, event, inviteeIds)
    await commit()
    return eventView(db, me, event)
  },

  async updateEvent(eventId, input) {
    validateEvent(input)
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const event = visibleEvent(db, me, eventId)
    ensure(event.creatorId === me, 'forbidden', 'Solo quien crea el evento puede editarlo.')
    Object.assign(event, {
      title: input.title.trim(),
      description: input.description.trim(),
      imageUrl: input.imageUrl,
      date: input.date,
      time: input.time,
      location: input.location.trim(),
      updatedAt: nowIso(),
    })
    await commit()
    return eventView(db, me, event)
  },

  async deleteEvent(eventId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const event = visibleEvent(db, me, eventId)
    ensure(event.creatorId === me, 'forbidden', 'Solo quien crea el evento puede eliminarlo.')
    db.events = db.events.filter((e) => e.id !== eventId)
    db.eventMembers = db.eventMembers.filter((m) => m.eventId !== eventId)
    dropNotifications(db, (n) => n.type === 'event_invite' && n.targetId === eventId)
    await commit()
  },

  /** The creator and anyone attending can invite their friends. */
  async invite(eventId, userIds) {
    validate(userIds.length ? null : 'Elige al menos a una persona.')
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const event = visibleEvent(db, me, eventId)
    const myStatus = db.eventMembers.find((m) => m.eventId === eventId && m.userId === me)?.status
    ensure(event.creatorId === me || myStatus === 'going' || myStatus === 'maybe', 'forbidden', 'No puedes invitar a este evento.')
    const count = inviteMany(db, me, event, userIds)
    await commit()
    return { event: eventView(db, me, event), invited: count }
  },

  async respond(eventId, status) {
    validate(RSVP.includes(status) && status !== 'pending' ? null : 'Respuesta no válida.')
    await latency(80, 200)
    const db = await getDb()
    const me = requireUserId(db)
    const event = visibleEvent(db, me, eventId)
    const member = db.eventMembers.find((m) => m.eventId === eventId && m.userId === me)
    ensure(member, 'forbidden', 'No estás invitado a este evento.')
    member.status = status
    member.respondedAt = nowIso()
    await commit()
    return eventView(db, me, event)
  },
}
