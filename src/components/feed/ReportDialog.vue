<script setup>
import { ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { useFeedStore } from '@/stores/feed'
import { errorMessage } from '@/services/errors'
import { REPORT_REASONS } from '@/config/app'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  postId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const feed = useFeedStore()

// DATA
const reason = ref('')
const sending = ref(false)
const error = ref('')

// METHODS
const send = async () => {
  sending.value = true
  error.value = ''
  try {
    await feed.reportPost(props.postId, reason.value)
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
      <p class="report__hint">Dejarás de verla en tu inicio. La persona que la publicó no sabrá quién la ha reportado.</p>
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
