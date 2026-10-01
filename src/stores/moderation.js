import { defineStore } from 'pinia'
import { reactive, ref } from 'vue'
import { moderationService } from '@/services/moderation.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'

/** Reporting content (anyone) and reviewing reports (moderators only). */
export const useModerationStore = defineStore('moderation', () => {
  const toast = useToast()

  /** null until checked. */
  const isModerator = ref(null)
  const reports = reactive({ status: 'idle', error: null, filter: 'pending', items: [] })

  const checkModerator = async () => {
    try {
      isModerator.value = await moderationService.isModerator()
    } catch {
      isModerator.value = false
    }
    return isModerator.value
  }

  /** Content with enough reports plus pending appeals (menu counter). */
  const pendingCount = ref(0)

  const loadPendingCount = async () => {
    if (!isModerator.value) return
    try {
      pendingCount.value = await moderationService.pendingCount()
    } catch {
      // Keeps the last value; it is refreshed again soon.
    }
  }

  /** Throws on error so the dialog can show it. */
  /** @param {{ illegalCategory?: string, details?: string }} [extra] illegal content */
  const report = async (kind, targetId, reason, extra = {}) => {
    await moderationService.reportContent(kind, targetId, reason, extra)
    toast.success('Gracias. Lo revisaremos.')
  }

  const loadReports = async (filter = reports.filter) => {
    reports.filter = filter
    reports.status = 'loading'
    reports.error = null
    try {
      reports.items = await moderationService.listReports(filter)
      reports.status = 'success'
    } catch (error) {
      reports.status = 'error'
      reports.error = errorMessage(error)
    }
  }

  const resolve = async (reportId, decision, options) => {
    try {
      await moderationService.resolveReport(reportId, decision, options)
      toast.success(decision === 'dismissed' ? 'Reporte descartado.' : 'Reporte resuelto.')
      await Promise.all([loadReports(), loadPendingCount()])
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  /** Notices about your own content removed by moderation (Inicio). */
  const notices = ref([])

  const loadNotices = async () => {
    try {
      notices.value = await moderationService.myNotices()
    } catch {
      // Informative only: they show up next time.
    }
  }

  const dismissNotice = async (noticeId) => {
    notices.value = notices.value.filter((n) => n.id !== noticeId)
    try {
      await moderationService.dismissNotice(noticeId)
    } catch {
      // It comes back next time if it could not be dismissed.
    }
  }

  /** Throws on error so the dialog can show it. */
  const appeal = async (noticeId, text) => {
    notices.value = await moderationService.appeal(noticeId, text)
    toast.success('Apelación enviada. Te avisaremos cuando la revisemos.')
  }

  // ---- Moderators: appeals ----------------------------------------------------------------
  const appeals = reactive({ status: 'idle', error: null, items: [] })

  const loadAppeals = async () => {
    appeals.status = 'loading'
    appeals.error = null
    try {
      appeals.items = await moderationService.listAppeals()
      appeals.status = 'success'
    } catch (error) {
      appeals.status = 'error'
      appeals.error = errorMessage(error)
    }
  }

  const resolveAppeal = async (appealId, accept) => {
    try {
      const { restored } = await moderationService.resolveAppeal(appealId, accept)
      appeals.items = appeals.items.filter((a) => a.id !== appealId)
      loadPendingCount()
      if (!accept) toast.success('Apelación rechazada. Se lo hemos comunicado.')
      else toast.success(restored ? 'Apelación aceptada: el contenido ha vuelto a su sitio.' : 'Apelación aceptada, pero el contenido no se ha podido restaurar.')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  /** Deletes the files of final removals; housekeeping, tried on each visit. */
  const cleanUpRemovedFiles = async () => {
    try {
      await moderationService.cleanUpRemovedFiles()
    } catch {
      // Tried again next time.
    }
  }

  return {
    isModerator,
    pendingCount,
    loadPendingCount,
    reports,
    notices,
    appeals,
    checkModerator,
    report,
    loadReports,
    resolve,
    loadNotices,
    dismissNotice,
    appeal,
    loadAppeals,
    resolveAppeal,
    cleanUpRemovedFiles,
  }
})
