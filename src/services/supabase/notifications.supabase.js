// Home page counters with Supabase. Same interface as local/notifications.local.js;
// the groups are built in notifications.groups.js.
import { currentUserId, rpc } from '@/services/supabase/client'
import { buildSummary, typesSeenAt } from '@/services/notifications.groups'
import { toSettings } from '@/services/supabase/mappers'

export const supabaseNotificationsService = {
  async getSummary() {
    const [me, state] = await Promise.all([currentUserId(), rpc('notification_state', {}, 'No se han podido cargar tus novedades.')])
    return buildSummary({
      me,
      prefs: toSettings(state.settings).notifications,
      conversationIds: state.conversation_ids,
      requestCount: state.request_count,
      invitationEventIds: state.invitation_event_ids,
      sharePhotoIds: state.share_photo_ids,
      unread: state.unread.map((n) => ({ type: n.type, targetId: n.target_id })),
    })
  },

  /** @param {{ targetId?: string, list?: 'wall' | 'posts' | 'photos' | 'tagged' | 'friends' }} place */
  async markSeen({ targetId = null, list = null }) {
    return rpc('mark_notifications_seen', { kinds: typesSeenAt(list), target: targetId }, 'No se han podido actualizar tus novedades.')
  },
}
