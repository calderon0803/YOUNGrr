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

  /** Throws on error so the dialog can show it. */
  const report = async (kind, targetId, reason) => {
    await moderationService.reportContent(kind, targetId, reason)
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
      await loadReports()
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return { isModerator, reports, checkModerator, report, loadReports, resolve }
})
