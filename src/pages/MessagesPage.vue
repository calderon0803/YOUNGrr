<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { MessageCircle, SquarePen } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import ConversationList from '@/components/messages/ConversationList.vue'
import ChatInvites from '@/components/messages/ChatInvites.vue'
import ChatThread from '@/components/messages/ChatThread.vue'
import NewMessageDialog from '@/components/messages/NewMessageDialog.vue'
import { useMessagesStore } from '@/stores/messages'

// STORES
const route = useRoute()
const messages = useMessagesStore()

// DATA
const composing = ref(false)

// COMPUTED
const activeId = computed(() => (route.params.id ? String(route.params.id) : null))

// LIFECYCLE
onMounted(() => messages.loadConversations())

// WATCHERS
// Refresh previews when switching conversation (new ones appear after the first message).
watch(activeId, () => messages.loadConversations())
</script>

<template>
  <div class="messages" :class="{ 'messages--thread': activeId }">
    <h1 class="visually-hidden">Mensajes</h1>
    <section class="messages__inbox panel" aria-labelledby="inbox-title">
      <header class="messages__inbox-head">
        <h2 id="inbox-title" class="messages__title">Conversaciones</h2>
        <button type="button" class="btn btn--ghost btn--sm" @click="composing = true">
          <SquarePen aria-hidden="true" />
          Nuevo
        </button>
      </header>
      <AsyncState :status="messages.inbox.status" :error="messages.inbox.error" :empty="!messages.inbox.items.length" @retry="messages.loadConversations()">
        <template #empty>
          <StateMessage compact :icon="MessageCircle" title="Todavía no tienes conversaciones." text="Escribe a un amigo para empezar.">
            <button type="button" class="btn btn--primary btn--sm" @click="composing = true">Nuevo mensaje</button>
          </StateMessage>
        </template>
        <ChatInvites />
        <ConversationList :conversations="messages.inbox.items" :active-id="activeId" />
      </AsyncState>
    </section>

    <div class="messages__thread panel">
      <ChatThread v-if="activeId" :key="activeId" :conversation-id="activeId" />
      <StateMessage v-else class="messages__placeholder" :icon="MessageCircle" title="Elige una conversación" text="O empieza una nueva con cualquiera de tus amigos." />
    </div>

    <NewMessageDialog :open="composing" @close="composing = false" />
  </div>
</template>

<style lang="scss" scoped>
.messages {
  &__inbox {
    overflow: hidden;
    border-radius: 0;
    border-right: 0;
    border-left: 0;
  }

  &__inbox-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: $space-2 $space-2 $space-2 $space-4;
    border-bottom: 1px solid $color-border;
  }

  &__title {
    font-size: $fs-md;
    font-weight: 700;
  }

  &__thread {
    display: none;
  }

  // Mobile: the conversation takes the whole screen above the bottom nav.
  &--thread {
    .messages__inbox {
      display: none;
    }

    .messages__thread {
      position: fixed;
      top: calc(#{$header-height} + env(safe-area-inset-top));
      right: 0;
      bottom: calc(#{$bottom-nav-height} + env(safe-area-inset-bottom));
      left: 0;
      z-index: 5;
      display: flex;
      flex-direction: column;
      border: 0;
      border-radius: 0;
    }
  }

  &__placeholder {
    margin: auto;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .messages {
    display: grid;
    grid-template-columns: 16rem minmax(0, 1fr);
    gap: $space-3;
    height: calc(100dvh - #{$header-height} - #{$space-10});

    &__inbox {
      overflow-y: auto;
      border-right: 1px solid $color-border;
      border-left: 1px solid $color-border;
      border-radius: $radius;
    }

    &__thread {
      display: flex;
      flex-direction: column;
      min-height: 0;
      overflow: hidden;
    }

    &--thread {
      .messages__inbox {
        display: block;
      }

      .messages__thread {
        position: static;
        border: 1px solid $color-border;
        border-radius: $radius;
      }
    }
  }
}

@media (min-width: $bp-desktop) {
  .messages {
    grid-template-columns: 19rem minmax(0, 1fr);
  }
}
</style>
