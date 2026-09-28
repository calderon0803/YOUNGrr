<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { Minus, X } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import NavBadge from '@/components/layout/NavBadge.vue'
import ChatThread from '@/components/messages/ChatThread.vue'
import { useMessagesStore } from '@/stores/messages'
import { fullName } from '@/utils/text'

// One open conversation in the chat dock. Clicking the header minimizes it
// to a bar that still shows new messages.

// PROPS
const props = defineProps({
  conversationId: { type: String, required: true },
  minimized: { type: Boolean, default: false },
})

// STORES
const messages = useMessagesStore()

// DATA
const thread = ref(null)

// COMPUTED
const state = computed(() => messages.threads[props.conversationId])
const other = computed(() => state.value?.conversation?.other ?? null)
const title = computed(() => (other.value ? fullName(other.value) : 'Conversación'))
const unread = computed(() => (props.minimized ? (state.value?.conversation?.unreadCount ?? 0) : 0))

// WATCHERS
// Ready to type when you open the window (once its thread has loaded).
watch(
  () => messages.dock.focusId === props.conversationId && state.value?.status === 'success',
  async (ready) => {
    if (!ready) return
    await nextTick()
    thread.value?.focus()
    messages.dock.focusId = null
  },
  { immediate: true },
)
</script>

<template>
  <section class="chat-window" :class="{ 'chat-window--minimized': minimized }" :aria-label="`Chat con ${title}`">
    <header class="chat-window__header">
      <button
        type="button"
        class="chat-window__title"
        :aria-expanded="!minimized"
        :aria-label="minimized ? `Abrir el chat con ${title}` : `Minimizar el chat con ${title}`"
        @click="messages.toggleWindow(conversationId)"
      >
        <UserAvatar v-if="other" :person="other" size="xs" />
        <span class="chat-window__name">{{ title }}</span>
        <NavBadge :count="unread" label="mensajes sin leer" />
      </button>
      <button
        v-if="!minimized"
        type="button"
        class="chat-window__action"
        aria-label="Minimizar"
        @click="messages.toggleWindow(conversationId)"
      >
        <Minus aria-hidden="true" />
      </button>
      <button type="button" class="chat-window__action" :aria-label="`Cerrar el chat con ${title}`" @click="messages.closeWindow(conversationId)">
        <X aria-hidden="true" />
      </button>
    </header>

    <div v-show="!minimized" class="chat-window__body">
      <ChatThread ref="thread" embedded :conversation-id="conversationId" />
    </div>
  </section>
</template>

<style lang="scss" scoped>
.chat-window {
  display: flex;
  flex-direction: column;
  width: 17rem;
  height: 23rem;
  overflow: hidden;
  background: $color-surface;
  border: 1px solid $color-border-strong;
  border-bottom: 0;
  border-radius: $radius $radius 0 0;
  box-shadow: 0 6px 18px $color-shadow;

  &--minimized {
    height: auto;
  }

  &__header {
    display: flex;
    align-items: center;
    flex-shrink: 0;
    height: 2.25rem;
    background: $color-header-bg;
    color: $color-on-brand;
  }

  &__title {
    @include reset-button;
    display: flex;
    flex: 1;
    align-items: center;
    gap: $space-2;
    min-width: 0;
    height: 100%;
    padding: 0 $space-2;
    font-weight: 700;
    color: inherit;

    &:focus-visible {
      @include focus-ring(-2px);
    }
  }

  &__name {
    @include truncate;
  }

  &__action {
    @include reset-button;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 100%;
    color: inherit;
    opacity: 0.85;

    svg {
      width: 1rem;
      height: 1rem;
    }

    &:hover {
      opacity: 1;
      background: $color-header-hover;
    }

    &:focus-visible {
      @include focus-ring(-2px);
    }
  }

  &__body {
    flex: 1;
    min-height: 0;
  }
}
</style>
