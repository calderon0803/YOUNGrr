// Home page counters with Supabase. Same interface as local/notifications.local.js;
// the groups are built in notifications.groups.js.
import { currentUserId, rpc } from '@/services/supabase/client'
import { buildSummary, typesSeenAt } from '@/services/notifications.groups'
import { toSettings, toSummary } from '@/services/supabase/mappers'
import { signPhotoUrls } from '@/services/supabase/storage'

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

  /** Photos behind the photo counters, with who did what. Marks nothing as seen. */
  async getPhotoNews(types) {
    const data = await rpc('photo_news', { kinds: types }, 'No se han podido cargar tus novedades.')
    const urls = await signPhotoUrls(data.map((b) => b.photo.storage_path))
    return data.map((b) => ({
      photo: {
        id: b.photo.id,
        url: urls[b.photo.storage_path] ?? null,
        width: b.photo.width,
        height: b.photo.height,
        caption: b.photo.caption ?? '',
        albumTitle: b.photo.album_title,
      },
      items: b.items.map((i) => ({ type: i.type, actor: toSummary(i.actor), createdAt: i.created_at })),
    }))
  },

  /** @param {{ targetId?: string, list?: 'wall' | 'posts' | 'photos' | 'tagged' | 'friends' }} place */
  async markSeen({ targetId = null, list = null }) {
    return rpc('mark_notifications_seen', { kinds: typesSeenAt(list), target: targetId }, 'No se han podido actualizar tus novedades.')
  },
}
