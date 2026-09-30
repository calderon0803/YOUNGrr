<script setup>
import { computed, ref, useId } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import EmojiPicker from '@/components/common/EmojiPicker.vue'
import { useAuthStore } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useEmojiInsert } from '@/composables/useEmojiInsert'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'

// PROPS
const props = defineProps({
  /** async (text) => void — the form clears itself when it resolves. */
  submit: { type: Function, required: true },
  placeholder: { type: String, default: 'Escribe un comentario...' },
  /** Length limit (replies in the Gallinero are shorter). */
  max: { type: Number, default: LIMITS.commentText },
})

// STORES
const auth = useAuthStore()
const toast = useToast()

// DATA
const text = ref('')
const sending = ref(false)
const input = ref(null)
const inputId = useId()
const { insert: addEmoji } = useEmojiInsert(input, text, () => props.max)

// COMPUTED
const canSend = computed(() => text.value.trim().length > 0 && text.value.length <= props.max && !sending.value)

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
      :maxlength="max"
      autocomplete="off"
      enterkeyhint="send"
    />
    <EmojiPicker @pick="addEmoji" />
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
