// Friends with Supabase. Same interface as local/friends.local.js.
// Every action runs as a database function and returns the person with the new status.
import { rpc } from '@/services/supabase/client'
import { toBirthday, toFriendRequest, toPerson } from '@/services/supabase/mappers'

export const supabaseFriendsService = {
  async listFriends(userId) {
    return (await rpc('list_friends', { target: userId }, 'No se han podido cargar los amigos.')).map(toPerson)
  },

  async listRequests() {
    const data = await rpc('list_friend_requests', {}, 'No se han podido cargar las solicitudes.')
    return { incoming: data.incoming.map(toFriendRequest), outgoing: data.outgoing.map(toFriendRequest) }
  },

  async sendRequest(toId) {
    return toPerson(await rpc('send_friend_request', { target: toId }, 'No se ha podido enviar la solicitud.'))
  },

  async cancelRequest(toId) {
    return toPerson(await rpc('cancel_friend_request', { target: toId }, 'No se ha podido cancelar la solicitud.'))
  },

  async acceptRequest(fromId) {
    return toPerson(await rpc('answer_friend_request', { sender: fromId, accept: true }, 'No se ha podido aceptar la solicitud.'))
  },

  async rejectRequest(fromId) {
    return toPerson(await rpc('answer_friend_request', { sender: fromId, accept: false }, 'No se ha podido rechazar la solicitud.'))
  },

  async upcomingBirthdays({ days = 30 } = {}) {
    return (await rpc('upcoming_birthdays', { days })).map(toBirthday)
  },

  async removeFriend(otherId) {
    return toPerson(await rpc('remove_friend', { other: otherId }, 'No se ha podido eliminar al amigo.'))
  },
}
