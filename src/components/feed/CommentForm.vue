<script setup>
import { computed, ref, useId } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useAuthStore } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'

// PROPS
const props = defineProps({
  /** async (text) => void — the form clears itself when it resolves. */
  submit: { type: Function, required: true },
  placeholder: { type: String, default: 'Escribe un comentario...' },
})

// STORES
const auth = useAuthStore()
const toast = useToast()

// DATA
const text = ref('')
const sending = ref(false)
const input = ref(null)
const inputId = useId()

// COMPUTED
const canSend = computed(() => text.value.trim().length > 0 && text.value.length <= LIMITS.commentText && !sending.value)

// METHODS
const send = async () => {
  if (!canSend.value) return
  sending.value = true
  try {
    await props.submit(text.value)
    text.value = ''
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    sending.value = false
  }
}

const focus = () => input.value?.focus()

defineExpose({ focus })
</script>

<template>
  <form class="comment-form" @submit.prevent="send">
    <UserAvatar :person="auth.me" size="sm" />
    <label class="visually-hidden" :for="inputId">Escribe un comentario</label>
    <input
      :id="inputId"
      ref="input"
      v-model="text"
      class="input comment-form__input"
      :placeholder="placeholder"
      :maxlength="LIMITS.commentText"
      autocomplete="off"
      enterkeyhint="send"
    />
    <button type="submit" class="btn btn--soft btn--sm" :disabled="!canSend">
      {{ sending ? 'Publicando…' : 'Publicar' }}
    </button>
  </form>
</template>

<style lang="scss" scoped>
.comment-form {
  display: flex;
  align-items: center;
  gap: $space-2;
  padding-top: $space-2;

  &__input {
    flex: 1;
    min-width: 0;
    min-height: 2.125rem;
    padding: $space-1 $space-3;
    font-size: $fs-base;
  }
}
</style>
