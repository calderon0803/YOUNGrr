<script setup>
import { onMounted, ref } from 'vue'
import { Info } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import { useModerationStore } from '@/stores/moderation'
import { errorMessage } from '@/services/errors'
import { fullDate } from '@/utils/time'

// Inicio: a simple notice when moderation removed something of yours after a
// report, with the reason (never who reported it). It can be appealed within
// its deadline; the answer comes back as another notice.

// STORES
const moderation = useModerationStore()

// DATA
const WHAT = {
  status: 'un estado tuyo',
  photo: 'una foto tuya',
  comment: 'un comentario tuyo',
  wall_message: 'un mensaje tuyo en un tablón',
  message: 'un mensaje privado tuyo',
}
const appealing = ref(null)
const text = ref('')
const sending = ref(false)
const error = ref('')

// METHODS
const what = (notice) => WHAT[notice.contentKind] ?? 'contenido tuyo'

const openAppeal = (notice) => {
  appealing.value = notice
  text.value = ''
  error.value = ''
}

const sendAppeal = async () => {
  sending.value = true
  error.value = ''
  try {
    await moderation.appeal(appealing.value.id, text.value)
    appealing.value = null
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    sending.value = false
  }
}

// LIFECYCLE
onMounted(() => moderation.loadNotices())
</script>

<template>
  <ul v-if="moderation.notices.length" class="notices" role="list">
    <li v-for="notice in moderation.notices" :key="notice.id" class="notices__item" role="status">
      <Info class="notices__icon" aria-hidden="true" />
      <div class="notices__body">
        <template v-if="notice.decision === 'accepted'">
          <p>
            Hemos revisado tu apelación y tenías razón.
            {{ notice.restored ? `Hemos restaurado ${what(notice)}.` : `No hemos podido restaurar ${what(notice)} porque ya no tenía dónde volver.` }}
          </p>
        </template>
        <template v-else-if="notice.decision === 'rejected'">
          <p>Hemos revisado tu apelación y mantenemos la retirada de {{ what(notice) }}.</p>
        </template>
        <template v-else>
          <p>Hemos retirado {{ what(notice) }} porque se reportó como «{{ notice.reason }}» y no cumple las normas de YOUNGrr.</p>
          <p v-if="notice.appealedAt" class="notices__hint">Has apelado. Te avisaremos cuando lo revisemos.</p>
          <p v-else-if="notice.canAppeal" class="notices__hint">Si crees que es un error, puedes apelar hasta el {{ fullDate(notice.appealUntil) }}.</p>
        </template>
      </div>
      <div v-if="!(notice.appealedAt && !notice.decision)" class="notices__actions">
        <button v-if="notice.canAppeal && !notice.decision" type="button" class="btn btn--soft btn--sm" @click="openAppeal(notice)">Apelar</button>
        <button type="button" class="btn btn--secondary btn--sm" @click="moderation.dismissNotice(notice.id)">Entendido</button>
      </div>
    </li>
  </ul>

  <BaseModal :open="!!appealing" title="Apelar la retirada" :busy="sending" @close="appealing = null">
    <form id="appeal-form" class="appeal-form" @submit.prevent="sendAppeal">
      <p v-if="appealing">
        Retiramos {{ what(appealing) }} por «{{ appealing.reason }}». Una persona de moderación volverá a revisarlo; si tienes
        razón, volverá a su sitio.
      </p>
      <label class="field">
        <span class="field__label">¿Por qué crees que es un error? (opcional)</span>
        <textarea v-model="text" class="textarea" rows="4" maxlength="500" />
      </label>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="sending" @click="appealing = null">Cancelar</button>
      <button type="submit" form="appeal-form" class="btn btn--primary" :disabled="sending">{{ sending ? 'Enviando…' : 'Enviar apelación' }}</button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.notices {
  display: flex;
  flex-direction: column;
  gap: $space-2;
  margin: 0;
  padding: $space-3 $space-3 0;

  &__item {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-start;
    gap: $space-2 $space-3;
    padding: $space-3;
    border: 1px solid $color-border-strong;
    border-radius: $radius;
    background: $color-surface-alt;
  }

  &__icon {
    flex-shrink: 0;
    width: 1.25rem;
    height: 1.25rem;
    color: $color-brand;
  }

  &__body {
    display: flex;
    flex: 1;
    flex-direction: column;
    gap: $space-1;
    min-width: 12rem;
    font-size: $fs-sm;
  }

  &__hint {
    color: $color-text-muted;
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: $space-2;
  }
}

.appeal-form {
  display: flex;
  flex-direction: column;
  gap: $space-3;
}
</style>
