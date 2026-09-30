<script setup>
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useMessagesStore } from '@/stores/messages'
import { useNotificationsStore } from '@/stores/notifications'
import { conversationAvatar, conversationName } from '@/utils/chat'

// Group chats you are invited to: nobody is added to one without accepting.

// PROPS
defineProps({
  compact: { type: Boolean, default: false },
})

// STORES
const messages = useMessagesStore()
const notifications = useNotificationsStore()
const router = useRouter()

// METHODS
const answer = async (conversationId, accept) => {
  const joined = await messages.answerChatInvite(conversationId, accept)
  notifications.loadSummary()
  if (joined) router.push({ name: 'conversation', params: { id: conversationId } })
}

// LIFECYCLE
onMounted(() => messages.loadChatInvites())
</script>

<template>
  <section v-if="messages.chatInvites.items.length" class="chat-invites" :class="{ 'chat-invites--compact': compact }" aria-label="Invitaciones a chats de grupo">
    <article v-for="invite in messages.chatInvites.items" :key="invite.conversation.id" class="chat-invites__item">
      <UserAvatar :person="conversationAvatar(invite.conversation)" size="sm" />
      <div class="chat-invites__body">
        <p>
          <strong>{{ invite.invitedBy?.firstName ?? 'Alguien' }}</strong> te invita a <strong>{{ conversationName(invite.conversation) }}</strong>
        </p>
        <div class="chat-invites__actions">
          <button type="button" class="btn btn--primary btn--sm" @click="answer(invite.conversation.id, true)">Entrar</button>
          <button type="button" class="btn btn--secondary btn--sm" @click="answer(invite.conversation.id, false)">Rechazar</button>
        </div>
      </div>
    </article>
  </section>
</template>

<style lang="scss" scoped>
.chat-invites {
  border-bottom: 1px solid $color-border;
  background: $color-brand-tint;

  &__item {
    display: flex;
    align-items: flex-start;
    gap: $space-3;
    padding: $space-3 $space-4;
    font-size: $fs-sm;

    & + & {
      border-top: 1px solid $color-border;
    }
  }

  &--compact &__item {
    padding: $space-2 $space-3;
  }

  &__body {
    flex: 1;
    min-width: 0;
  }

  &__actions {
    display: flex;
    gap: $space-2;
    margin-top: $space-2;
  }
}
</style>
