<script setup>
import { ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { useFeedStore } from '@/stores/feed'
import { useModerationStore } from '@/stores/moderation'
import { errorMessage } from '@/services/errors'
import { REPORT_REASONS } from '@/config/app'

// Reports a status, photo, comment, wall message or profile to the moderators.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  /** 'status' | 'photo' | 'comment' | 'wall_message' | 'profile' | 'message' */
  kind: { type: String, default: 'status' },
  targetId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const feed = useFeedStore()
const moderation = useModerationStore()

// DATA
const reason = ref('')
const sending = ref(false)
const error = ref('')

// METHODS
const send = async () => {
  sending.value = true
  error.value = ''
  try {
    // A reported status also leaves the reporter's news.
    if (props.kind === 'status') await feed.reportPost(props.targetId, reason.value)
    else await moderation.report(props.kind, props.targetId, reason.value)
    emit('close')
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    sending.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => open && (reason.value = ''),
)
</script>

<template>
  <BaseModal :open="open" title="Reportar" size="sm" :busy="sending" @close="emit('close')">
    <form id="report-form" @submit.prevent="send">
      <fieldset class="report">
        <legend class="report__legend">¿Qué ocurre con esto?</legend>
        <label v-for="option in REPORT_REASONS" :key="option" class="check report__option">
          <input v-model="reason" type="radio" name="report-reason" :value="option" />
          {{ option }}
        </label>
      </fieldset>
      <p class="report__hint">
        Llega a moderación cuando lo reportan varias personas. Nadie sabrá quién ha hecho el reporte.
      </p>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="sending" @click="emit('close')">Cancelar</button>
      <button type="submit" form="report-form" class="btn btn--danger" :disabled="!reason || sending">
        {{ sending ? 'Enviando…' : 'Reportar' }}
      </button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.report {
  display: grid;
  gap: $space-2;
  margin: 0;
  padding: 0;
  border: 0;

  &__legend {
    margin-bottom: $space-2;
    font-weight: 600;
  }

  &__option {
    padding: $space-1 0;
  }

  &__hint {
    margin-top: $space-4;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
