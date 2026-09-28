import { eventDateTime, isPastEvent } from '@/utils/time'

const when = (e) => eventDateTime(e.date, e.time).getTime()

/** Splits your events into pending invitations, upcoming and past (newest first). */
export const splitEvents = (events) => {
  const upcoming = events.filter((e) => !isPastEvent(e.date, e.time)).sort((a, b) => when(a) - when(b))
  return {
    invitations: upcoming.filter((e) => e.myStatus === 'pending'),
    upcoming: upcoming.filter((e) => e.myStatus !== 'pending'),
    past: events.filter((e) => isPastEvent(e.date, e.time)).sort((a, b) => when(b) - when(a)),
  }
}
