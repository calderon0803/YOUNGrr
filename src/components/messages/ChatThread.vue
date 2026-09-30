<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { ArrowLeft, Users } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import MessageComposer from '@/components/messages/MessageComposer.vue'
import ReportDialog from '@/components/feed/ReportDialog.vue'
import GroupChatDialog from '@/components/messages/GroupChatDialog.vue'
import { useMessagesStore } from '@/stores/messages'
import { useAuthStore } from '@/stores/auth'
import { useConfirm } from '@/composables/useConfirm'
import { clockTime, fullDate } from '@/utils/time'
import { fullName } from '@/utils/text'
import { conversationAvatar, conversationName } from '@/utils/chat'

// PROPS
const props = defineProps({
  conversationId: { type: String, required: true },
  /** Inside a chat window, which has its own header. */
  embedded: { type: Boolean, default: false },
})

// STORES
const messages = useMessagesStore()
const auth = useAuthStore()
const { confirm } = useConfirm()

// DATA
const scroller = ref(null)
/** Id of the message being reported. */
const reportingId = ref(null)
const composer = ref(null)
const managing = ref(false)

// COMPUTED
const state = computed(() => messages.threads[props.conversationId] ?? { status: 'loading', error: null, conversation: null, messages: [] })
const conversation = computed(() => state.value.conversation)
const other = computed(() => conversation.value?.other ?? null)
const isGroup = computed(() => conversation.value?.kind === 'group')
const name = computed(() => conversationName(conversation.value))
// In groups, each message shows who wrote it (by first name).
const senders = computed(() => Object.fromEntries((conversation.value?.members ?? []).map((p) => [p.id, p])))
const senderName = (id) => senders.value[id]?.firstName ?? 'Alguien'

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
const remove = async (message) => {
  const ok = await confirm({
    title: 'Eliminar mensaje',
    message: `Desaparecerá para ${isGroup.value ? 'todos' : 'los dos'} y quedará «Mensaje eliminado». No se puede deshacer.`,
    confirmLabel: 'Eliminar',
    danger: true,
  })
  if (ok) messages.deleteMessage(props.conversationId, message.id)
}

const scrollToEnd = async () => {
  await nextTick()
  if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight
}

defineExpose({ focus: () => composer.value?.focus() })

// WATCHERS
// A chat window loads its thread through the dock (minimized ones stay unread).
watch(() => props.conversationId, (id) => !props.embedded && messages.loadThread(id), { immediate: true })
watch(() => state.value.messages.length, scrollToEnd)
</script>

<template>
  <section class="thread" :class="{ 'thread--embedded': embedded }" :aria-label="conversation ? `Conversación: ${name}` : 'Conversación'">
    <header v-if="!embedded" class="thread__header">
      <RouterLink class="thread__back btn btn--ghost btn--icon" :to="{ name: 'messages' }" aria-label="Volver a las conversaciones">
        <ArrowLeft aria-hidden="true" />
      </RouterLink>
      <template v-if="other">
        <UserAvatar :person="other" size="sm" />
        <RouterLink class="thread__name" :to="{ name: 'profile', params: { id: other.id } }">{{ fullName(other) }}</RouterLink>
      </template>
      <template v-else-if="isGroup">
        <UserAvatar :person="conversationAvatar(conversation)" size="sm" />
        <span class="thread__name">{{ name }}</span>
        <button type="button" class="thread__people btn btn--ghost btn--sm" @click="managing = true">
          <Users aria-hidden="true" />
          {{ conversation.members.length }}
        </button>
      </template>
    </header>

    <div ref="scroller" class="thread__scroll" aria-live="polite">
      <AsyncState :status="state.status" :error="state.error" :empty="!state.messages.length" @retry="messages.loadThread(conversationId)">
        <template #empty>
          <StateMessage
            compact
            :title="isGroup ? `Empieza a hablar en ${name}.` : `Empieza a hablar con ${other?.firstName ?? 'tu amigo'}.`"
            :text="isGroup ? 'Los mensajes solo los ven las personas del grupo.' : 'Los mensajes solo los veis vosotros dos.'"
          />
        </template>
        <div v-for="day in days" :key="day.label" class="thread__day">
          <p class="thread__date"><span>{{ day.label }}</span></p>
          <ul class="thread__list" role="list">
            <li
              v-for="message in day.items"
              :key="message.id"
              class="bubble"
              :class="{
                'bubble--mine': message.senderId === auth.meId,
                'bubble--pending': message.pending,
                'bubble--failed': message.failed,
                'bubble--deleted': message.deleted,
              }"
            >
              <span v-if="isGroup && message.senderId !== auth.meId" class="bubble__sender">{{ senderName(message.senderId) }}</span>
              <span v-else class="visually-hidden">{{ message.senderId === auth.meId ? 'Tú' : other?.firstName }}:</span>
              <span v-if="message.deleted" class="bubble__text">Mensaje eliminado</span>
              <span v-else class="bubble__text user-text">{{ message.text }}</span>
              <span class="bubble__meta">
                <button
                  v-if="message.senderId !== auth.meId && !message.deleted"
                  type="button"
                  class="bubble__delete"
                  aria-label="Reportar mensaje"
                  @click="reportingId = message.id"
                >
                  Reportar
                </button>
                <button
                  v-if="message.senderId === auth.meId && !message.deleted && !message.pending && !message.failed"
                  type="button"
                  class="bubble__delete"
                  aria-label="Eliminar mensaje"
                  @click="remove(message)"
                >
                  Eliminar
                </button>
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

    <ReportDialog v-if="reportingId" :open="!!reportingId" kind="message" :target-id="reportingId" @close="reportingId = null" />
    <MessageComposer ref="composer" v-if="state.status === 'success' && conversation" :recipient="name" :send="(text) => messages.send(conversationId, text)" />
    <GroupChatDialog v-if="isGroup && !embedded" :open="managing" :conversation-id="conversationId" @close="managing = false" />
  </section>
</template>

<style lang="scss" scoped>
.thread {
  &__people {
    margin-left: auto;
  }

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

  &--embedded &__scroll {
    padding: $space-2;
  }

  &__list {
    display: flex;
    flex-direction: column;
    gap: $space-1;
    margin: 0;
  }
}

.bubble {
  &__sender {
    display: block;
    font-size: $fs-xs;
    font-weight: 700;
    color: $color-brand-strong;
  }

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

  &__discard,
  &__delete {
    @include reset-button;
    text-decoration: underline;
  }

  &__delete {
    margin-right: $space-1;
  }

  &--deleted {
    font-style: italic;
    opacity: 0.7;
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

/* With a mouse, "Eliminar" only shows on the message you point at. */
@media (hover: hover) {
  .bubble__delete {
    opacity: 0;

    &:focus-visible {
      opacity: 1;
    }
  }

  .bubble:hover .bubble__delete {
    opacity: 1;
  }
}
</style>
