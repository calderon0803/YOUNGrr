<script setup>
import { computed, ref, useId } from 'vue'
import { Send } from 'lucide-vue-next'
import EmojiPicker from '@/components/common/EmojiPicker.vue'
import MentionMenu from '@/components/common/MentionMenu.vue'
import { useEmojiInsert } from '@/composables/useEmojiInsert'
import { useMentions } from '@/composables/useMentions'
import { LIMITS } from '@/utils/validation'

// PROPS
const props = defineProps({
  /** (text, mentions) => void */
  send: { type: Function, required: true },
  recipient: { type: String, required: true },
  /** People who can be mentioned with "@" (group chats). */
  people: { type: Array, default: () => [] },
})

// DATA
const inputId = useId()
const text = ref('')
const input = ref(null)
const { insert: addEmoji } = useEmojiInsert(input, text, () => LIMITS.messageText)
const mention = useMentions(input, text, () => props.people)

// COMPUTED
const canSend = computed(() => text.value.trim().length > 0 && text.value.length <= LIMITS.messageText)

// METHODS
const submit = () => {
  if (!canSend.value) return
  props.send(text.value, mention.mentions.value)
  text.value = ''
  mention.reset()
  input.value?.focus()
}

const focus = () => input.value?.focus()

const onKeydown = (event) => {
  if (mention.onKeydown(event)) return
  // Enter sends, Shift+Enter adds a new line (desktop habit).
  if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
    event.preventDefault()
    submit()
  }
}

defineExpose({ focus })
</script>

<template>
  <form class="composer" @submit.prevent="submit">
    <label class="visually-hidden" :for="inputId">Mensaje para {{ recipient }}</label>
    <div class="composer__field">
    <textarea
      :id="inputId"
      ref="input"
      v-model="text"
      class="composer__input"
      rows="1"
      placeholder="Escribe un mensaje..."
      :maxlength="LIMITS.messageText"
      enterkeyhint="send"
      @keydown="onKeydown"
      @input="mention.onInput"
      @blur="mention.close"
    />
    <MentionMenu :suggestions="mention.suggestions.value" :active="mention.active.value" placement="top" @pick="mention.choose" />
    </div>
    <EmojiPicker placement="top" @pick="addEmoji" />
    <button type="submit" class="btn btn--primary btn--icon" aria-label="Enviar mensaje" :disabled="!canSend">
      <Send aria-hidden="true" />
    </button>
  </form>
</template>

<style lang="scss" scoped>
.composer {
  display: flex;
  align-items: flex-end;
  gap: $space-2;
  padding: $space-3;
  border-top: 1px solid $color-border;
  background: $color-surface;

  &__field {
    position: relative;
    display: flex;
    flex: 1;
    min-width: 0;
  }

  &__input {
    flex: 1;
    min-height: 2.25rem;
    max-height: 8rem;
    padding: $space-2 $space-3;
    border: 1px solid $color-border-strong;
    border-radius: $radius;
    background: $color-surface-alt;
    color: $color-text;
    line-height: 1.35;
    resize: none;
    field-sizing: content;

    &:focus-visible {
      outline: 2px solid $color-focus;
      outline-offset: -1px;
      background: $color-surface;
    }
  }
}
</style>
