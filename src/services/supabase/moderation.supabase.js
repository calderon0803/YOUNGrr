// Reports and moderation with Supabase. Same interface as local/moderation.local.js.
// Reports are only readable by moderators, through list_reports().
import { rpc } from '@/services/supabase/client'
import { toSummary } from '@/services/supabase/mappers'
import { removePhotos, signPhotoUrls } from '@/services/supabase/storage'
import { validate } from '@/services/errors'
import { ILLEGAL_CATEGORIES, ILLEGAL_REASON, MODERATION_RULES, REPORT_REASONS } from '@/config/app'

const toReport = (json, urls) => ({
  id: json.id,
  targetType: json.target_type,
  targetId: json.target_id,
  // How many people reported it, and for which reasons ({ reason: count }).
  reportCount: json.report_count ?? 1,
  reasons: json.reasons ?? {},
  // Reported as illegal: it is reviewed even with a single report.
  illegal: !!json.illegal,
  illegalCategories: json.illegal_categories ?? [],
  details: json.details ?? [],
  createdAt: json.created_at,
  lastReportedAt: json.last_reported_at ?? json.created_at,
  status: json.status,
  snapshot: {
    text: json.snapshot.text ?? json.snapshot.caption ?? json.snapshot.bio ?? '',
    name: json.snapshot.name ?? null,
    photoUrl: urls[json.snapshot.storage_path] ?? null,
    storagePath: json.snapshot.storage_path ?? null,
    // Gallinero content: the group it was in.
    group: json.snapshot.group ?? null,
  },
  contentExists: !!json.content_exists,
  contentRemoved: !!json.content_removed,
  targetOwner: json.target_owner ? toSummary(json.target_owner) : null,
  resolvedBy: json.resolved_by ? toSummary(json.resolved_by) : null,
  resolvedAt: json.resolved_at,
  resolutionNote: json.resolution_note ?? '',
})

const toNotice = (n) => ({
  id: n.id,
  contentKind: n.content_kind,
  reason: n.reason,
  // The rule of the terms it broke, and whether a person decided it.
  rule: n.rule ?? null,
  automated: !!n.automated,
  removedAt: n.removed_at,
  appealUntil: n.appeal_until,
  canAppeal: !!n.can_appeal,
  appealedAt: n.appealed_at ?? null,
  decision: n.decision ?? null,
  restored: n.restored ?? null,
})

export const supabaseModerationService = {
  /** @param {'status' | 'photo' | 'comment' | 'wall_message' | 'profile' | 'message' | 'group_post' | 'group_reply'} kind */
  /** @param {{ illegalCategory?: string, details?: string }} [extra] illegal content: type and explanation */
  async reportContent(kind, targetId, reason, { illegalCategory = null, details = null } = {}) {
    const illegal = reason === ILLEGAL_REASON
    validate(
      REPORT_REASONS.includes(reason) || illegal ? null : 'Elige un motivo.',
      illegal && !ILLEGAL_CATEGORIES.some((c) => c.key === illegalCategory) ? 'Elige qué tipo de contenido ilegal es.' : null,
      illegal && (details ?? '').trim().length < 10 ? 'Explica por qué es ilegal.' : null,
    )
    await rpc(
      'report_content',
      { kind, target: targetId, reason, details: illegal ? details : null, illegal_category: illegal ? illegalCategory : null },
      'No se ha podido enviar el reporte.',
    )
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

  /** Content that reached the minimum of reports, plus pending appeals. */
  async pendingCount() {
    return rpc('moderation_pending_count', {}, 'No se ha podido revisar la moderación.')
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
   * @param {{ removeContent?: boolean, note?: string, rule?: string }} options rule: the norm a removal is based on
   */
  async resolveReport(reportId, decision, { removeContent = false, note = '', rule = null } = {}) {
    validate(removeContent && !MODERATION_RULES.some((r) => r.key === rule) ? 'Elige qué norma incumple.' : null)
    // A removed photo keeps its file while it can be appealed (see cleanUpRemovedFiles).
    await rpc('resolve_report', { target: reportId, decision, remove_content: removeContent, note, rule: removeContent ? rule : null }, 'No se ha podido guardar la decisión.')
  },
}
