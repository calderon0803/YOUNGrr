// Profile wall ("tablón") with Supabase. Same interface as local/wall.local.js.
import { rpc } from '@/services/supabase/client'
import { toWallMessage } from '@/services/supabase/mappers'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'

export const supabaseWallService = {
  async listWall(profileId) {
    const data = await rpc('list_wall', { target: profileId }, 'No se ha podido cargar el tablón.')
    return { messages: data.messages.map(toWallMessage), canWrite: data.can_write }
  },

  async addWallMessage(profileId, text) {
    validate(rules.required(text, 'El mensaje'), rules.max(text, LIMITS.wallText, 'El mensaje'))
    return toWallMessage(await rpc('add_wall_message', { target: profileId, body: text }, 'No se ha podido publicar el mensaje.'))
  },

  async deleteWallMessage(messageId) {
    await rpc('delete_wall_message', { target: messageId }, 'No se ha podido borrar el mensaje.')
  },
}
