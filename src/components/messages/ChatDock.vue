<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { ChevronDown, MessageCircle, SquarePen } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import NavBadge from '@/components/layout/NavBadge.vue'
import ConversationList from '@/components/messages/ConversationList.vue'
import ChatInvites from '@/components/messages/ChatInvites.vue'
import ChatWindow from '@/components/messages/ChatWindow.vue'
import NewMessageDialog from '@/components/messages/NewMessageDialog.vue'
import { useMessagesStore } from '@/stores/messages'
import { useMediaQuery } from '@/composables/useMediaQuery'
import { BREAKPOINTS, CHAT_MAX_WINDOWS, CHAT_POLL_INTERVAL_MS } from '@/config/app'

// Chat at the bottom right (tablet and desktop): a panel with your
// conversations that folds into a bar, and the open chats to its left.
// Opening a conversation anywhere in the app (/messages/:id) lands here.

// STORES
const messages = useMessagesStore()

// DATA
const isDesktop = useMediaQuery(`(min-width: ${BREAKPOINTS.desktop}px)`)
const composing = ref(false)
let poll = null

// COMPUTED
// Only the windows that fit; the rest come back when there is room.
const windows = computed(() => messages.dock.windows.slice(0, isDesktop.value ? CHAT_MAX_WINDOWS.desktop : CHAT_MAX_WINDOWS.tablet))

// METHODS
const onVisibility = () => {
  if (document.visibilityState === 'visible') messages.refreshDock()
}

// LIFECYCLE
onMounted(() => {
  messages.restoreDock()
  poll = setInterval(() => document.visibilityState === 'visible' && messages.refreshDock(), CHAT_POLL_INTERVAL_MS)
  document.addEventListener('visibilitychange', onVisibility)
})

onBeforeUnmount(() => {
  clearInterval(poll)
  document.removeEventListener('visibilitychange', onVisibility)
})
</script>

<template>
  <aside class="dock" aria-label="Chat">
    <section class="dock__panel" :class="{ 'dock__panel--open': messages.dock.open }">
      <header class="dock__header">
        <button
          type="button"
          class="dock__toggle"
          :aria-expanded="messages.dock.open"
          aria-controls="chat-panel"
          @click="messages.toggleDock()"
        >
          <MessageCircle aria-hidden="true" />
          <span class="dock__title">Chat</span>
          <NavBadge :count="messages.unreadTotal" label="conversaciones sin leer" />
          <ChevronDown v-if="messages.dock.open" class="dock__chevron" aria-hidden="true" />
        </button>
        <button v-if="messages.dock.open" type="button" class="dock__new" aria-label="Nuevo mensaje" @click="composing = true">
          <SquarePen aria-hidden="true" />
        </button>
      </header>

      <div v-show="messages.dock.open" id="chat-panel" class="dock__body">
        <AsyncState
          :status="messages.inbox.status"
          :error="messages.inbox.error"
          :empty="!messages.inbox.items.length"
          @retry="messages.loadConversations()"
        >
          <template #empty>
            <StateMessage compact :icon="MessageCircle" title="Todavía no tienes conversaciones." text="Escribe a un amigo para empezar.">
              <button type="button" class="btn btn--primary btn--sm" @click="composing = true">Nuevo mensaje</button>
            </StateMessage>
          </template>
          <ChatInvites compact />
          <ConversationList compact :conversations="messages.inbox.items" />
        </AsyncState>
      </div>
    </section>

    <ChatWindow v-for="w in windows" :key="w.id" :conversation-id="w.id" :minimized="w.minimized" />

    <NewMessageDialog :open="composing" @close="composing = false" />
  </aside>
</template>

<style lang="scss" scoped>
.dock {
  position: fixed;
  right: $space-4;
  bottom: 0;
  z-index: $z-chat;
  display: flex;
  flex-direction: row-reverse;
  align-items: flex-end;
  gap: $space-2;
  pointer-events: none;

  > * {
    pointer-events: auto;
  }

  &__panel {
    display: flex;
    flex-direction: column;
    width: 15rem;
    overflow: hidden;
    background: $color-surface;
    border: 1px solid $color-border-strong;
    border-bottom: 0;
    border-radius: $radius $radius 0 0;
    box-shadow: 0 6px 18px $color-shadow;

    &--open {
      height: 26rem;
    }
  }

  &__header {
    display: flex;
    align-items: center;
    flex-shrink: 0;
    height: 2.25rem;
    background: $color-header-bg;
    color: $color-on-brand;
  }

  &__toggle,
  &__new {
    @include reset-button;
    display: flex;
    align-items: center;
    height: 100%;
    color: inherit;

    svg {
      width: 1rem;
      height: 1rem;
    }

    &:hover {
      background: $color-header-hover;
    }

    &:focus-visible {
      @include focus-ring(-2px);
    }
  }

  &__toggle {
    flex: 1;
    gap: $space-2;
    padding: 0 $space-3;
    font-weight: 700;
  }

  &__chevron {
    margin-left: auto;
  }

  &__new {
    justify-content: center;
    width: 2.25rem;
  }

  &__body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }
}
</style>
