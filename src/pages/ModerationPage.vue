<script setup>
import { computed, onMounted, reactive, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ShieldCheck } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import TabNav from '@/components/common/TabNav.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import AppealsList from '@/components/moderation/AppealsList.vue'
import { useModerationStore } from '@/stores/moderation'
import { useConfirm } from '@/composables/useConfirm'
import { APPEAL_DAYS } from '@/config/app'
import { plural } from '@/utils/text'

// Reports for moderators: who reported what, why and when, with a copy of the
// content kept at the time. Only reachable for moderators (router guard) and
// the data only comes from the moderator-only database functions.

// STORES
const route = useRoute()
const moderation = useModerationStore()
const { confirm } = useConfirm()

// DATA
const TABS = [
  { key: 'pending', label: 'Pendientes' },
  { key: 'resolved', label: 'Resueltos' },
  { key: 'dismissed', label: 'Descartados' },
  { key: 'appeals', label: 'Apelaciones' },
]
const KIND_LABEL = { status: 'Estado', photo: 'Foto', comment: 'Comentario', wall_message: 'Mensaje del tablón', profile: 'Perfil', message: 'Mensaje privado' }
const notes = reactive({})

// COMPUTED
const filter = computed(() => (TABS.some((t) => t.key === route.query.estado) ? route.query.estado : 'pending'))

// METHODS
// "Es spam (6) · Contenido ofensivo (4)", most frequent first.
const reasonsText = (report) =>
  Object.entries(report.reasons)
    .sort((a, b) => b[1] - a[1])
    .map(([reason, n]) => `${reason} (${n})`)
    .join(' · ')

const tabRoute = (key) => ({ query: key === 'pending' ? {} : { estado: key } })

const resolve = async (report, decision, removeContent = false) => {
  if (removeContent) {
    const ok = await confirm({
      title: 'Retirar el contenido',
      message: `Dejará de verse para todo el mundo. Su dueño podrá apelar durante ${APPEAL_DAYS} días; si no apela o se rechaza la apelación, se borrará del todo.`,
      confirmLabel: 'Retirar',
      danger: true,
    })
    if (!ok) return
  }
  await moderation.resolve(report.id, decision, { removeContent, note: notes[report.id] ?? '' })
}

// LIFECYCLE
// Final removals (rejected or not appealed in time) lose their photo files.
onMounted(() => moderation.cleanUpRemovedFiles())

// WATCHERS
watch(filter, (value) => value !== 'appeals' && moderation.loadReports(value), { immediate: true })
</script>

<template>
  <div class="moderation">
    <section class="panel" aria-labelledby="moderation-title">
      <h1 id="moderation-title" class="panel-title">Moderación</h1>
      <TabNav label="Estado de los reportes" :tabs="TABS" :active="filter" :to="tabRoute" />

      <AppealsList v-if="filter === 'appeals'" />
      <AsyncState
        v-else
        :status="moderation.reports.status"
        :error="moderation.reports.error"
        :empty="!moderation.reports.items.length"
        @retry="moderation.loadReports(filter)"
      >
        <template #empty>
          <StateMessage :icon="ShieldCheck" title="No hay reportes aquí." />
        </template>

        <ul class="moderation__list" role="list">
          <li v-for="report in moderation.reports.items" :key="report.id" class="report">
            <p class="report__head">
              <span class="report__kind">{{ KIND_LABEL[report.targetType] }}</span>
              <strong>{{ plural(report.reportCount, 'reporte', 'reportes') }}</strong>
              <span class="report__reasons">{{ reasonsText(report) }}</span>
              <RelativeTime class="report__when" :value="report.lastReportedAt" />
            </p>

            <p class="report__who">
              De:
              <PersonLink v-if="report.targetOwner" :person="report.targetOwner" />
              <em v-else>cuenta eliminada</em>
            </p>

            <blockquote class="report__content">
              <p v-if="report.snapshot.name"><strong>{{ report.snapshot.name }}</strong></p>
              <img v-if="report.snapshot.photoUrl" :src="report.snapshot.photoUrl" alt="Foto reportada" class="report__photo" />
              <p v-if="report.snapshot.text" class="user-text">{{ report.snapshot.text }}</p>
              <p v-if="!report.snapshot.text && !report.snapshot.photoUrl && !report.snapshot.name" class="report__muted">Sin contenido guardado.</p>
            </blockquote>
            <p class="report__muted">
              {{ report.contentRemoved ? 'Contenido retirado.' : report.contentExists ? 'El contenido sigue publicado.' : 'Su autor ya lo borró.' }}
            </p>

            <template v-if="report.status === 'pending'">
              <label class="visually-hidden" :for="`note-${report.id}`">Nota de la decisión</label>
              <textarea
                :id="`note-${report.id}`"
                v-model="notes[report.id]"
                class="input report__note"
                rows="2"
                maxlength="500"
                placeholder="Nota interna (opcional)"
              />
              <div class="report__actions">
                <button type="button" class="btn btn--secondary btn--sm" @click="resolve(report, 'dismissed')">Descartar</button>
                <button type="button" class="btn btn--secondary btn--sm" @click="resolve(report, 'resolved')">Resolver</button>
                <button
                  v-if="report.targetType !== 'profile' && report.contentExists"
                  type="button"
                  class="btn btn--danger btn--sm"
                  @click="resolve(report, 'resolved', true)"
                >
                  Resolver y retirar el contenido
                </button>
              </div>
            </template>
            <p v-else class="report__muted">
              {{ report.status === 'resolved' ? 'Resuelto' : 'Descartado' }}
              <template v-if="report.resolvedBy"> por {{ report.resolvedBy.firstName }}</template>
              <template v-if="report.resolvedAt"> · <RelativeTime :value="report.resolvedAt" /></template>
              <template v-if="report.resolutionNote"> · «{{ report.resolutionNote }}»</template>
            </p>
          </li>
        </ul>
      </AsyncState>
    </section>
  </div>
</template>

<style lang="scss" scoped>
.moderation {
  max-width: 44rem;
  margin: 0 auto;

  &__list {
    margin: 0;
    padding: 0;
  }
}

.report {
  display: flex;
  flex-direction: column;
  gap: $space-2;
  padding: $space-3;

  & + & {
    border-top: 1px solid $color-border;
  }

  &__head {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: $space-2;
  }

  &__kind {
    padding: 0.1rem $space-2;
    border-radius: $radius-sm;
    background: $color-brand-tint;
    color: $color-brand-strong;
    font-size: $fs-xs;
    font-weight: 700;
  }

  &__when,
  &__reasons,
  &__who,
  &__muted {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__content {
    margin: 0;
    padding: $space-2 $space-3;
    border-left: 3px solid $color-border-strong;
    background: $color-surface-alt;
  }

  &__photo {
    display: block;
    max-width: 100%;
    max-height: 16rem;
    border-radius: $radius-sm;
  }

  &__note {
    width: 100%;
    font-size: $fs-sm;
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: $space-2;
  }
}
</style>
