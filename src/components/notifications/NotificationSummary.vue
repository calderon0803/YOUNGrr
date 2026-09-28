<script setup>
import { computed, markRaw, useId } from 'vue'
import { ChartNoAxesColumn, CalendarDays, Images, MessageCircle, MessageSquare, MessageSquareText, Tag, UserCheck, UserPlus } from 'lucide-vue-next'
import GrrIcon from '@/components/common/GrrIcon.vue'
import { useNotificationsStore } from '@/stores/notifications'
import { useAuthStore } from '@/stores/auth'
import { useUserStore } from '@/stores/user'
import { fullName } from '@/utils/text'

// Your box on the home page, as in Tuenti: your name, the private visit counter
// of your profile (only you see it) and the counters of what is new, grouped by
// kind. Each line takes you to where it is dealt with; once visited (or
// answered) it disappears.

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
    <h2 :id="titleId" class="summary__name">
      <RouterLink v-if="auth.me" :to="{ name: 'profile', params: { id: auth.meId } }">{{ fullName(auth.me) }}</RouterLink>
      <span class="visually-hidden">: tus novedades</span>
    </h2>
    <p class="summary__visits">
      <ChartNoAxesColumn class="summary__icon summary__icon--visits" aria-hidden="true" />
      <span><strong>{{ visitsLabel }}</strong> {{ visits === 1 ? 'visita' : 'visitas' }} a tu perfil</span>
    </p>
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
          <span>{{ group.count }} {{ group.label }}</span>
        </RouterLink>
      </li>
    </ul>
    <p v-else-if="notifications.summary.status === 'success'" class="summary__empty">No tienes novedades.</p>
  </section>
</template>

<style lang="scss" scoped>
.summary {
  padding: $space-3 0 $space-2;

  &__name {
    padding: 0 $space-3;
    font-family: $font-body;
    font-size: $fs-md;
    font-weight: 700;

    a {
      color: $color-link;
    }
  }

  &__visits {
    display: flex;
    align-items: center;
    gap: $space-1;
    padding: $space-1 $space-3 $space-2;
    font-size: $fs-sm;
    color: $color-text-muted;

    strong {
      color: $color-text;
    }
  }

  &__list {
    margin: 0;
    padding: 0;
  }

  // Tuenti's green news lines.
  &__item {
    display: flex;
    align-items: center;
    gap: $space-2;
    padding: 0.2rem $space-3;
    font-size: $fs-sm;
    font-weight: 600;
    color: $color-success;

    &:hover {
      text-decoration: none;

      span {
        text-decoration: underline;
      }
    }
  }

  &__icon {
    flex-shrink: 0;
    width: 0.95rem;
    height: 0.95rem;
    color: $color-success;

    &--grr {
      color: $color-grr;
    }

    &--visits {
      color: $color-brand;
    }
  }

  &__empty {
    padding: 0.2rem $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
