<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { ArrowLeft } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import MessageComposer from '@/components/messages/MessageComposer.vue'
import { useMessagesStore } from '@/stores/messages'
import { useAuthStore } from '@/stores/auth'
import { clockTime, fullDate } from '@/utils/time'
import { fullName } from '@/utils/text'

// PROPS
const props = defineProps({
  conversationId: { type: String, required: true },
})

// STORES
const messages = useMessagesStore()
const auth = useAuthStore()

// DATA
const scroller = ref(null)

// COMPUTED
const state = computed(() => messages.threads[props.conversationId] ?? { status: 'loading', error: null, conversation: null, messages: [] })
const other = computed(() => state.value.conversation?.other)

// Messages grouped by day, with a date separator for each.
const days = computed(() => {
  const groups = []
  for (const message of state.value.messages) {
    const label = fullDate(message.createdAt)
    const last = groups[groups.length - 1]
    if (last?.label === label) last.items.push(message)
    else groups.push({ label, items: [message] })
  }
  return groups
})

// METHODS
const scrollToEnd = async () => {
  await nextTick()
  if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight
}

// WATCHERS
watch(() => props.conversationId, (id) => messages.loadThread(id), { immediate: true })
watch(() => state.value.messages.length, scrollToEnd)
</script>

<template>
  <section class="thread" :aria-label="other ? `Conversación con ${fullName(other)}` : 'Conversación'">
    <header class="thread__header">
      <RouterLink class="thread__back btn btn--ghost btn--icon" :to="{ name: 'messages' }" aria-label="Volver a las conversaciones">
        <ArrowLeft aria-hidden="true" />
      </RouterLink>
      <template v-if="other">
        <UserAvatar :person="other" size="sm" />
        <RouterLink class="thread__name" :to="{ name: 'profile', params: { id: other.id } }">{{ fullName(other) }}</RouterLink>
      </template>
    </header>

    <div ref="scroller" class="thread__scroll" aria-live="polite">
      <AsyncState :status="state.status" :error="state.error" :empty="!state.messages.length" @retry="messages.loadThread(conversationId)">
        <template #empty>
          <StateMessage compact :title="`Empieza a hablar con ${other?.firstName ?? 'tu amigo'}.`" text="Los mensajes solo los veis vosotros dos." />
        </template>
        <div v-for="day in days" :key="day.label" class="thread__day">
          <p class="thread__date"><span>{{ day.label }}</span></p>
          <ul class="thread__list" role="list">
            <li
              v-for="message in day.items"
              :key="message.id"
              class="bubble"
              :class="{ 'bubble--mine': message.senderId === auth.meId, 'bubble--pending': message.pending, 'bubble--failed': message.failed }"
            >
              <span class="visually-hidden">{{ message.senderId === auth.meId ? 'Tú' : other?.firstName }}:</span>
              <span class="bubble__text user-text">{{ message.text }}</span>
              <span class="bubble__meta">
                <template v-if="message.failed">
                  No enviado ·
                  <button type="button" class="bubble__discard" @click="messages.discardFailed(conversationId, message.id)">Descartar</button>
                </template>
                <template v-else-if="message.pending">Enviando…</template>
                <time v-else :datetime="message.createdAt">{{ clockTime(message.createdAt) }}</time>
              </span>
            </li>
          </ul>
        </div>
      </AsyncState>
    </div>

    <MessageComposer v-if="state.status === 'success' && other" :recipient="fullName(other)" :send="(text) => messages.send(conversationId, text)" />
  </section>
</template>

<style lang="scss" scoped>
.thread {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;

  &__header {
    display: flex;
    align-items: center;
    gap: $space-2;
    min-height: 3.25rem;
    padding: 0 $space-3;
    border-bottom: 1px solid $color-border;
  }

  &__name {
    font-weight: 700;
    color: $color-text;
  }

  &__scroll {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: $space-3 $space-4;
    background: $color-surface-alt;
  }

  &__date {
    display: flex;
    justify-content: center;
    margin: $space-3 0;

    span {
      padding: 0.1rem $space-2;
      border-radius: $radius-sm;
      background: $color-surface-hover;
      font-size: $fs-xs;
      font-weight: 600;
      color: $color-text-muted;
    }
  }

  &__list {
    display: flex;
    flex-direction: column;
    gap: $space-1;
    margin: 0;
  }
}

.bubble {
  display: flex;
  flex-direction: column;
  max-width: 78%;
  padding: $space-2 $space-3 $space-1;
  align-self: flex-start;
  background: $color-surface;
  border: 1px solid $color-border;
  border-radius: $radius-lg $radius-lg $radius-lg $radius-sm;
  animation: bubble-in 160ms $ease-out;

  &__meta {
    align-self: flex-end;
    font-size: 0.6875rem;
    color: $color-text-muted;
  }

  &__discard {
    @include reset-button;
    text-decoration: underline;
  }

  &--mine {
    align-self: flex-end;
    background: $color-brand;
    border-color: $color-brand;
    color: $color-on-brand;
    border-radius: $radius-lg $radius-lg $radius-sm $radius-lg;

    .bubble__meta {
      color: $color-on-brand-muted;
    }
  }

  &--pending {
    opacity: 0.7;
  }

  &--failed {
    background: $color-danger-soft;
    border-color: $color-danger;
    color: $color-text;

    .bubble__meta {
      color: $color-danger;
    }
  }
}

@keyframes bubble-in {
  from {
    opacity: 0;
    transform: translateY(0.25rem);
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .thread__back {
    display: none;
  }
}
</style>
