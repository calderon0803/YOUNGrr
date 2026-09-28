// Grr and comments with Supabase (posts and photos). Same interface as local/interactions.local.js.
import { rpc } from '@/services/supabase/client'
import { toComment, toSummary } from '@/services/supabase/mappers'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'

export const supabaseInteractionsService = {
  /** Unique per user and content in the database; removing a Grr never notifies. */
  async setGrr(targetType, targetId, value) {
    const state = await rpc('set_grr', { target_type: targetType, target: targetId, value }, 'No se ha podido guardar el Grr.')
    return { grrCount: state.grr_count, hasGrr: state.has_grr }
  },

  async listGrrers(targetType, targetId) {
    return (await rpc('list_grrers', { target_type: targetType, target: targetId })).map(toSummary)
  },

  async listComments(targetType, targetId) {
    return (await rpc('list_comments', { target_type: targetType, target: targetId }, 'No se han podido cargar los comentarios.')).map(toComment)
  },

  async addComment(targetType, targetId, text) {
    validate(rules.required(text, 'El comentario'), rules.max(text, LIMITS.commentText, 'El comentario'))
    return toComment(await rpc('add_comment', { target_type: targetType, target: targetId, body: text }, 'No se ha podido publicar el comentario.'))
  },

  async deleteComment(commentId) {
    await rpc('delete_comment', { target: commentId }, 'No se ha podido eliminar el comentario.')
  },
}
