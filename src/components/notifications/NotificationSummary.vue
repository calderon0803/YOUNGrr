<script setup>
import { markRaw, useId } from 'vue'
import { CalendarDays, Images, MessageCircle, MessageSquare, Tag, UserCheck, UserPlus } from 'lucide-vue-next'
import GrrIcon from '@/components/common/GrrIcon.vue'
import { useNotificationsStore } from '@/stores/notifications'

// Home-page counters, grouped by kind. Each line takes you to where it is dealt
// with; once visited (or answered) it disappears.

// STORES
const notifications = useNotificationsStore()

// DATA
const titleId = useId()
const ICONS = {
  messages: markRaw(MessageCircle),
  requests: markRaw(UserPlus),
  events: markRaw(CalendarDays),
  shares: markRaw(Images),
  comments_posts: markRaw(MessageSquare),
  comments_photos: markRaw(MessageSquare),
  grr_posts: markRaw(GrrIcon),
  grr_photos: markRaw(GrrIcon),
  tags: markRaw(Tag),
  owners_accepted: markRaw(Images),
  friends_accepted: markRaw(UserCheck),
}
const GRR_KEYS = ['grr_posts', 'grr_photos']
</script>

<template>
  <section class="panel summary" :aria-labelledby="titleId">
    <h2 :id="titleId" class="panel-title">Novedades</h2>
    <ul v-if="notifications.summary.groups.length" class="summary__list" role="list">
      <li v-for="group in notifications.summary.groups" :key="group.key">
        <RouterLink class="summary__item" :to="group.link">
          <component
            :is="ICONS[group.key]"
            class="summary__icon"
            :class="{ 'summary__icon--grr': GRR_KEYS.includes(group.key) }"
            v-bind="GRR_KEYS.includes(group.key) ? { active: true } : {}"
            aria-hidden="true"
          />
          <span><strong class="summary__count">{{ group.count }}</strong> {{ group.label }}</span>
        </RouterLink>
      </li>
    </ul>
    <p v-else-if="notifications.summary.status === 'success'" class="summary__empty">No tienes novedades.</p>
  </section>
</template>

<style lang="scss" scoped>
.summary {
  &__list {
    margin: 0;
    padding: $space-1 0;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-2 $space-4;
    color: $color-text;

    &:hover {
      background: $color-surface-hover;
      text-decoration: none;

      span {
        text-decoration: underline;
      }
    }
  }

  &__icon {
    flex-shrink: 0;
    width: 1.1rem;
    height: 1.1rem;
    color: $color-brand;

    &--grr {
      color: $color-grr;
    }
  }

  &__count {
    color: $color-brand-strong;
  }

  &__empty {
    padding: $space-3 $space-4;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
