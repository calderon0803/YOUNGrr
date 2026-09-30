<script setup>
import { onMounted } from 'vue'
import { Scale } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import { useModerationStore } from '@/stores/moderation'
import { useConfirm } from '@/composables/useConfirm'

// Moderation > Apelaciones: people who think a removal was a mistake. Accepting
// puts the content back where it was; rejecting deletes it for good.

// STORES
const moderation = useModerationStore()
const { confirm } = useConfirm()

// DATA
const KIND_LABEL = {
  status: 'Estado',
  photo: 'Foto',
  comment: 'Comentario',
  wall_message: 'Mensaje del tablón',
  message: 'Mensaje privado',
  group_post: 'Publicación del Gallinero',
  group_reply: 'Respuesta del Gallinero',
}

// METHODS
const decide = async (appeal, accept) => {
  const ok = await confirm(
    accept
      ? { title: 'Aceptar la apelación', message: 'El contenido volverá a su sitio, con sus comentarios y Grr, y se le avisará.', confirmLabel: 'Aceptar' }
      : { title: 'Rechazar la apelación', message: 'El contenido se borrará del todo y se le avisará. No se puede deshacer.', confirmLabel: 'Rechazar', danger: true },
  )
  if (ok) moderation.resolveAppeal(appeal.id, accept)
}

// LIFECYCLE
onMounted(() => moderation.loadAppeals())
</script>

<template>
  <AsyncState :status="moderation.appeals.status" :error="moderation.appeals.error" :empty="!moderation.appeals.items.length" @retry="moderation.loadAppeals()">
    <template #empty>
      <StateMessage :icon="Scale" title="No hay apelaciones pendientes." />
    </template>
    <ul class="appeals" role="list">
      <li v-for="appeal in moderation.appeals.items" :key="appeal.id" class="appeal">
        <p class="appeal__head">
          <span class="appeal__kind">{{ KIND_LABEL[appeal.contentKind] }}</span>
          <span>Motivo del reporte: <strong>{{ appeal.reason }}</strong></span>
          <RelativeTime class="appeal__muted" :value="appeal.appealedAt" />
        </p>
        <p class="appeal__muted">
          De:
          <PersonLink v-if="appeal.owner" :person="appeal.owner" />
          <em v-else>cuenta eliminada</em>
          · Retirado <RelativeTime :value="appeal.removedAt" />
        </p>
        <blockquote class="appeal__content">
          <img v-if="appeal.photoUrl" :src="appeal.photoUrl" alt="Contenido retirado" class="appeal__photo" />
          <p v-if="appeal.text" class="user-text">{{ appeal.text }}</p>
          <p v-if="!appeal.text && !appeal.photoUrl" class="appeal__muted">Sin texto.</p>
        </blockquote>
        <p class="appeal__why">
          <strong>Su explicación:</strong>
          <span class="user-text">{{ appeal.appealText || 'No ha añadido ninguna.' }}</span>
        </p>
        <div class="appeal__actions">
          <button type="button" class="btn btn--secondary btn--sm" @click="decide(appeal, true)">Aceptar y restaurar</button>
          <button type="button" class="btn btn--danger btn--sm" @click="decide(appeal, false)">Rechazar</button>
        </div>
      </li>
    </ul>
  </AsyncState>
</template>

<style lang="scss" scoped>
.appeals {
  margin: 0;
  padding: 0;
}

.appeal {
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

  &__why {
    display: flex;
    flex-direction: column;
    gap: $space-1;
    font-size: $fs-sm;
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: $space-2;
  }
}
</style>
