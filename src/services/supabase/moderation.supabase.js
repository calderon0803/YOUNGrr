// Reports and moderation with Supabase. Same interface as local/moderation.local.js.
// Reports are only readable by moderators, through list_reports().
import { rpc } from '@/services/supabase/client'
import { toSummary } from '@/services/supabase/mappers'
import { removePhotos, signPhotoUrls } from '@/services/supabase/storage'
import { validate } from '@/services/errors'
import { REPORT_REASONS } from '@/config/app'

const toReport = (json, urls) => ({
  id: json.id,
  targetType: json.target_type,
  targetId: json.target_id,
  reason: json.reason,
  createdAt: json.created_at,
  status: json.status,
  snapshot: {
    text: json.snapshot.text ?? json.snapshot.caption ?? json.snapshot.bio ?? '',
    name: json.snapshot.name ?? null,
    photoUrl: urls[json.snapshot.storage_path] ?? null,
    storagePath: json.snapshot.storage_path ?? null,
  },
  contentExists: !!json.content_exists,
  contentRemoved: !!json.content_removed,
  reporter: json.reporter ? toSummary(json.reporter) : null,
  targetOwner: json.target_owner ? toSummary(json.target_owner) : null,
  resolvedBy: json.resolved_by ? toSummary(json.resolved_by) : null,
  resolvedAt: json.resolved_at,
  resolutionNote: json.resolution_note ?? '',
})

const toNotice = (n) => ({
  id: n.id,
  contentKind: n.content_kind,
  reason: n.reason,
  removedAt: n.removed_at,
  appealUntil: n.appeal_until,
  canAppeal: !!n.can_appeal,
  appealedAt: n.appealed_at ?? null,
  decision: n.decision ?? null,
  restored: n.restored ?? null,
})

export const supabaseModerationService = {
  /** @param {'status' | 'photo' | 'comment' | 'wall_message' | 'profile' | 'message'} kind */
  async reportContent(kind, targetId, reason) {
    validate(REPORT_REASONS.includes(reason) ? null : 'Elige un motivo.')
    await rpc('report_content', { kind, target: targetId, reason }, 'No se ha podido enviar el reporte.')
  },

  /** Notices about your content removed by moderation, with the appeal state. */
  async myNotices() {
    return (await rpc('my_moderation_notices', {}, 'No se han podido cargar los avisos.')).map(toNotice)
  },

  async dismissNotice(noticeId) {
    await rpc('dismiss_moderation_notice', { target: noticeId }, 'No se ha podido cerrar el aviso.')
  },

  async appeal(noticeId, text) {
    validate(text.trim().length > 500 ? 'La explicación no puede superar los 500 caracteres.' : null)
    return (await rpc('appeal_removal', { target: noticeId, body: text }, 'No se ha podido enviar la apelación.')).map(toNotice)
  },

  async listAppeals() {
    const data = await rpc('list_appeals', {}, 'No se han podido cargar las apelaciones.')
    const urls = await signPhotoUrls(data.map((a) => a.storage_path)).catch(() => ({}))
    return data.map((a) => ({
      id: a.id,
      contentKind: a.content_kind,
      reason: a.reason,
      owner: a.owner ? toSummary(a.owner) : null,
      removedAt: a.removed_at,
      appealText: a.appeal_text ?? '',
      appealedAt: a.appealed_at,
      text: a.text ?? '',
      photoUrl: urls[a.storage_path] ?? null,
    }))
  },

  /** @returns {Promise<{ restored: boolean }>} */
  async resolveAppeal(appealId, accept) {
    return rpc('resolve_appeal', { target: appealId, accept }, 'No se ha podido guardar la decisión.')
  },

  /** Deletes the photo files of final removals (rejected or not appealed in time). */
  async cleanUpRemovedFiles() {
    const paths = await rpc('moderation_files_to_delete', {}, 'No se han podido revisar los archivos retirados.')
    if (!paths.length) return
    await removePhotos(paths)
    await rpc('mark_moderation_files_deleted', { paths }, 'No se han podido revisar los archivos retirados.')
  },

  async isModerator() {
    return !!(await rpc('is_moderator', {}, 'No se ha podido comprobar tu acceso.'))
  },

  /** @param {'pending' | 'resolved' | 'dismissed' | 'all'} filter */
  async listReports(filter = 'pending') {
    const data = await rpc('list_reports', { filter }, 'No se han podido cargar los reportes.')
    // Moderators can see the reported photos (the Storage policy allows only those).
    const urls = await signPhotoUrls(data.map((r) => r.snapshot?.storage_path)).catch(() => ({}))
    return data.map((r) => toReport(r, urls))
  },

  /**
   * @param {'resolved' | 'dismissed'} decision
   * @param {{ removeContent?: boolean, note?: string }} options
   */
  async resolveReport(reportId, decision, { removeContent = false, note = '' } = {}) {
    // A removed photo keeps its file while it can be appealed (see cleanUpRemovedFiles).
    await rpc('resolve_report', { target: reportId, decision, remove_content: removeContent, note }, 'No se ha podido guardar la decisión.')
  },
}
