<script setup>
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useAuthStore } from '@/stores/auth'
import { useNow } from '@/composables/useNow'
import { fullName } from '@/utils/text'
import { shortStamp } from '@/utils/time'

// PROPS
defineProps({
  conversations: { type: Array, required: true },
  activeId: { type: String, default: null },
  /** Tighter rows for the chat panel. */
  compact: { type: Boolean, default: false },
})

// STORES
const auth = useAuthStore()

// DATA
const now = useNow()
</script>

<template>
  <ul class="conversations" :class="{ 'conversations--compact': compact }" role="list" aria-label="Conversaciones">
    <li v-for="c in conversations" :key="c.id">
      <RouterLink
        class="conversations__item"
        :class="{ 'conversations__item--active': c.id === activeId, 'conversations__item--unread': c.unreadCount > 0 }"
        :to="{ name: 'conversation', params: { id: c.id } }"
        :aria-current="c.id === activeId ? 'page' : undefined"
      >
        <UserAvatar :person="c.other" :size="compact ? 'sm' : 'md'" />
        <span class="conversations__body">
          <span class="conversations__top">
            <span class="conversations__name">{{ fullName(c.other) }}</span>
            <time v-if="c.lastMessage" class="conversations__time" :datetime="c.lastMessage.createdAt">{{ shortStamp(c.lastMessage.createdAt, now) }}</time>
          </span>
          <span class="conversations__preview">
            <template v-if="c.lastMessage">
              <template v-if="c.lastMessage.senderId === auth.meId">Tú: </template>
              <em v-if="c.lastMessage.deleted">Mensaje eliminado</em>
              <template v-else>{{ c.lastMessage.text }}</template>
            </template>
          </span>
        </span>
        <span v-if="c.unreadCount" class="conversations__dot"><span class="visually-hidden">{{ c.unreadCount }} sin leer</span></span>
      </RouterLink>
    </li>
  </ul>
</template>

<style lang="scss" scoped>
.conversations {
  margin: 0;

  &__item {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-3 $space-4;
    border-left: 3px solid transparent;
    color: $color-text;

    &:hover {
      background: $color-surface-hover;
      text-decoration: none;
    }

    &--active {
      border-left-color: $color-brand;
      background: $color-brand-tint;
    }

    &--unread {
      .conversations__name,
      .conversations__preview {
        font-weight: 700;
        color: $color-text;
      }
    }
  }

  li + li &__item {
    border-top: 1px solid $color-border;
  }

  &__body {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
  }

  &__top {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: $space-2;
  }

  &__name {
    @include truncate;
    font-weight: 600;
  }

  &__time {
    flex-shrink: 0;
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__preview {
    @include truncate;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &--compact &__item {
    gap: $space-2;
    padding: $space-2 $space-3;
  }

  &__dot {
    flex-shrink: 0;
    width: 0.6rem;
    height: 0.6rem;
    border-radius: 50%;
    background: $color-grr;
  }
}
</style>
