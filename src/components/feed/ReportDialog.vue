<script setup>
import { computed, ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { useFeedStore } from '@/stores/feed'
import { useModerationStore } from '@/stores/moderation'
import { errorMessage } from '@/services/errors'
import { ILLEGAL_CATEGORIES, ILLEGAL_REASON, REPORT_REASONS } from '@/config/app'

// Reports content to the moderators. "Es ilegal" (with its type and an
// explanation) reaches them with a single report; the other reasons need
// several people.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  /** 'status' | 'photo' | 'comment' | 'wall_message' | 'profile' | 'message' | 'group_post' | 'group_reply' */
  kind: { type: String, default: 'status' },
  targetId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const feed = useFeedStore()
const moderation = useModerationStore()

// DATA
const reason = ref('')
const category = ref('')
const details = ref('')
const sending = ref(false)
const error = ref('')

// COMPUTED
const illegal = computed(() => reason.value === ILLEGAL_REASON)
const canSend = computed(() => !!reason.value && (!illegal.value || (!!category.value && details.value.trim().length >= 10)) && !sending.value)

// METHODS
const send = async () => {
  sending.value = true
  error.value = ''
  try {
    if (illegal.value) await moderation.report(props.kind, props.targetId, ILLEGAL_REASON, { illegalCategory: category.value, details: details.value })
    // A reported status also leaves the reporter's news.
    else if (props.kind === 'status') await feed.reportPost(props.targetId, reason.value)
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
  (open) => {
    if (!open) return
    reason.value = ''
    category.value = ''
    details.value = ''
  },
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
        <label class="check report__option">
          <input v-model="reason" type="radio" name="report-reason" :value="ILLEGAL_REASON" />
          Es ilegal
        </label>
      </fieldset>
      <template v-if="illegal">
        <fieldset class="report report--illegal">
          <legend class="report__legend">¿Qué tipo de contenido ilegal?</legend>
          <label v-for="option in ILLEGAL_CATEGORIES" :key="option.key" class="check report__option">
            <input v-model="category" type="radio" name="report-illegal" :value="option.key" />
            {{ option.label }}
          </label>
        </fieldset>
        <label class="field report__details">
          <span class="field__label">Explica por qué es ilegal</span>
          <textarea v-model="details" class="textarea" rows="3" maxlength="1000" placeholder="Qué ocurre y, si lo sabes, qué ley incumple" />
        </label>
        <p class="report__hint">
          Lo revisa moderación aunque solo lo avises tú. Al enviarlo declaras de buena fe que lo que cuentas es cierto.
        </p>
      </template>
      <p v-else class="report__hint">
        Llega a moderación cuando lo reportan varias personas. Nadie sabrá quién ha hecho el reporte.
      </p>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="sending" @click="emit('close')">Cancelar</button>
      <button type="submit" form="report-form" class="btn btn--danger" :disabled="!canSend">
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

  &--illegal {
    margin-top: $space-4;
  }

  &__details {
    margin-top: $space-3;
  }

  &__hint {
    margin-top: $space-4;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
