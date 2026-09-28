// Events with Supabase. Same interface as local/events.local.js. The image is
// stored in the private "photos" bucket and only the invited people can read it.
import { currentUserId, rpc } from '@/services/supabase/client'
import { removePhotos, signPhotoUrls, uploadPhoto } from '@/services/supabase/storage'
import { toSummary } from '@/services/supabase/mappers'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { splitEvents } from '@/utils/events'

const RSVP = ['going', 'maybe', 'declined']

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

const toEvent = (json, urls) => ({
  id: json.id,
  creatorId: json.creator_id,
  title: json.title,
  description: json.description ?? '',
  imageUrl: urls[json.image_path] ?? null,
  date: json.date,
  time: json.time,
  location: json.location,
  createdAt: json.created_at,
  updatedAt: json.updated_at,
  creator: toSummary(json.creator),
  isCreator: !!json.is_creator,
  myStatus: json.my_status ?? null,
  counts: json.counts,
  members: json.members.map((m) => ({ person: toSummary(m.person), status: m.status })),
})

export const eventsWithImages = async (items) => {
  const urls = await signPhotoUrls(items.map((e) => e.image_path))
  return items.map((e) => toEvent(e, urls))
}

const one = async (json) => (await eventsWithImages([json]))[0]

const isNewImage = (value) => typeof value === 'string' && value.startsWith('data:')

const params = (input, imagePath) => ({
  title: input.title,
  description: input.description,
  image_path: imagePath,
  event_date: input.date,
  event_time: input.time,
  location: input.location,
})

export const supabaseEventsService = {
  async listEvents() {
    return splitEvents(await eventsWithImages(await rpc('list_events', {}, 'No se han podido cargar los eventos.')))
  },

  async getEvent(eventId) {
    return one(await rpc('get_event', { target: eventId }, 'No se ha podido cargar el evento.'))
  },

  async createEvent(input, inviteeIds = []) {
    validateEvent(input)
    const imagePath = isNewImage(input.imageUrl) ? await uploadPhoto(await currentUserId(), input.imageUrl) : null
    try {
      return one(await rpc('create_event', { ...params(input, imagePath), invitees: inviteeIds }, 'No se ha podido crear el evento.'))
    } catch (error) {
      await removePhotos([imagePath]).catch(() => {})
      throw error
    }
  },

  async updateEvent(eventId, input) {
    validateEvent(input)
    let imagePath = null
    if (isNewImage(input.imageUrl)) imagePath = await uploadPhoto(await currentUserId(), input.imageUrl)
    // Unchanged image: keep the stored file (the form only has its signed URL).
    else if (input.imageUrl) imagePath = (await rpc('get_event', { target: eventId }, 'No se ha podido guardar el evento.')).image_path
    try {
      const data = await rpc('update_event', { target: eventId, ...params(input, imagePath) }, 'No se ha podido guardar el evento.')
      await removePhotos([data.removed_path]).catch(() => {})
      return one(data.event)
    } catch (error) {
      if (isNewImage(input.imageUrl)) await removePhotos([imagePath]).catch(() => {})
      throw error
    }
  },

  async deleteEvent(eventId) {
    const imagePath = await rpc('delete_event', { target: eventId }, 'No se ha podido eliminar el evento.')
    await removePhotos([imagePath]).catch(() => {})
  },

  /** The creator and anyone attending can invite their friends. */
  async invite(eventId, userIds) {
    validate(userIds.length ? null : 'Elige al menos a una persona.')
    const data = await rpc('invite_to_event', { target: eventId, people: userIds }, 'No se ha podido enviar la invitación.')
    return { event: await one(data.event), invited: data.invited }
  },

  async respond(eventId, status) {
    validate(RSVP.includes(status) ? null : 'Respuesta no válida.')
    return one(await rpc('respond_event', { target: eventId, answer: status }, 'No se ha podido guardar tu respuesta.'))
  },
}
