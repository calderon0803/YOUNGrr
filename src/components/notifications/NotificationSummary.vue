<script setup>
import { computed, markRaw, useId } from 'vue'
import { CalendarDays, Eye, Images, MessageCircle, MessageSquare, MessageSquareText, Tag, UserCheck, UserPlus } from 'lucide-vue-next'
import GrrIcon from '@/components/common/GrrIcon.vue'
import { useNotificationsStore } from '@/stores/notifications'
import { useAuthStore } from '@/stores/auth'
import { useUserStore } from '@/stores/user'

// Home-page counters, grouped by kind. Each line takes you to where it is dealt
// with; once visited (or answered) it disappears. Below them, the private visit
// counter of your profile (only you see it).

// STORES
const notifications = useNotificationsStore()
const auth = useAuthStore()
const user = useUserStore()

// DATA
const titleId = useId()
const ICONS = {
  wall: markRaw(MessageSquareText),
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

// COMPUTED
const visits = computed(() => user.profiles[auth.meId]?.data?.visits ?? auth.me?.visitCount ?? 0)
const visitsLabel = computed(() => new Intl.NumberFormat('es-ES', { useGrouping: 'always' }).format(visits.value))
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
    <p class="summary__visits">
      <Eye class="summary__icon" aria-hidden="true" />
      <span>Visitas a tu perfil: <strong class="summary__count">{{ visitsLabel }}</strong></span>
    </p>
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

  &__visits {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-2 $space-4 $space-3;
    border-top: 1px solid $color-border;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__empty {
    padding: $space-3 $space-4;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
