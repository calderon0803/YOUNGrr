<script setup>
import { computed, ref, useId } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import EmojiPicker from '@/components/common/EmojiPicker.vue'
import MentionMenu from '@/components/common/MentionMenu.vue'
import { useAuthStore } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useEmojiInsert } from '@/composables/useEmojiInsert'
import { useMentions } from '@/composables/useMentions'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'

// PROPS
const props = defineProps({
  /** async (text, mentions) => void — the form clears itself when it resolves. */
  submit: { type: Function, required: true },
  placeholder: { type: String, default: 'Escribe un comentario...' },
  /** Length limit (replies in the Gallinero are shorter). */
  max: { type: Number, default: LIMITS.commentText },
  /** People who can be mentioned with "@" (none: no mentions). */
  people: { type: Array, default: () => [] },
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
const mention = useMentions(input, text, () => props.people)

// COMPUTED
const canSend = computed(() => text.value.trim().length > 0 && text.value.length <= props.max && !sending.value)

// METHODS
const send = async () => {
  if (!canSend.value) return
  sending.value = true
  try {
    await props.submit(text.value, mention.mentions.value)
    text.value = ''
    mention.reset()
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
    <div class="comment-form__field">
    <input
      :id="inputId"
      ref="input"
      v-model="text"
      class="input comment-form__input"
      :placeholder="placeholder"
      :maxlength="max"
      autocomplete="off"
      enterkeyhint="send"
      @input="mention.onInput"
      @keydown="mention.onKeydown"
      @blur="mention.close"
    />
    <MentionMenu :suggestions="mention.suggestions.value" :active="mention.active.value" @pick="mention.choose" />
    </div>
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

  &__field {
    position: relative;
    flex: 1;
    min-width: 0;
  }

  &__input {
    width: 100%;
    min-height: 2.125rem;
    padding: $space-1 $space-3;
    font-size: $fs-base;
  }
}
</style>
