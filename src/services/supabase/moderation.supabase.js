// Reports and moderation with Supabase. Same interface as local/moderation.local.js.
// Reports are only readable by moderators, through list_reports().
import { rpc } from '@/services/supabase/client'
import { toSummary } from '@/services/supabase/mappers'
import { signPhotoUrls } from '@/services/supabase/storage'
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
  },
  contentExists: !!json.content_exists,
  contentRemoved: !!json.content_removed,
  reporter: json.reporter ? toSummary(json.reporter) : null,
  targetOwner: json.target_owner ? toSummary(json.target_owner) : null,
  resolvedBy: json.resolved_by ? toSummary(json.resolved_by) : null,
  resolvedAt: json.resolved_at,
  resolutionNote: json.resolution_note ?? '',
})

export const supabaseModerationService = {
  /** @param {'status' | 'photo' | 'comment' | 'wall_message' | 'profile'} kind */
  async reportContent(kind, targetId, reason) {
    validate(REPORT_REASONS.includes(reason) ? null : 'Elige un motivo.')
    await rpc('report_content', { kind, target: targetId, reason }, 'No se ha podido enviar el reporte.')
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

  /** @param {'resolved' | 'dismissed'} decision */
  async resolveReport(reportId, decision, { removeContent = false, note = '' } = {}) {
    await rpc('resolve_report', { target: reportId, decision, remove_content: removeContent, note }, 'No se ha podido guardar la decisión.')
  },
}
