<script setup>
import { computed, markRaw } from 'vue'
import { House, Menu, MessageCircle, Users } from 'lucide-vue-next'
import NavBadge from '@/components/layout/NavBadge.vue'
import { useMessagesStore } from '@/stores/messages'
import { useFriendsStore } from '@/stores/friends'
import { useEventsStore } from '@/stores/events'
import { useNotificationsStore } from '@/stores/notifications'

// STORES
const messages = useMessagesStore()
const friends = useFriendsStore()
const events = useEventsStore()
const notifications = useNotificationsStore()

// COMPUTED
const items = computed(() => [
  { to: { name: 'home' }, label: 'Inicio', icon: markRaw(House), count: notifications.total, badge: 'novedades' },
  { to: { name: 'friends' }, label: 'Amigos', icon: markRaw(Users), count: friends.incomingCount, badge: 'solicitudes pendientes' },
  { to: { name: 'messages' }, label: 'Mensajes', icon: markRaw(MessageCircle), count: messages.unreadTotal, badge: 'sin leer' },
  { to: { name: 'more' }, label: 'Más', icon: markRaw(Menu), count: events.pendingCount, badge: 'invitaciones a eventos' },
])
</script>

<template>
  <nav class="bottom-nav" aria-label="Navegación principal">
    <ul class="bottom-nav__list" role="list">
      <li v-for="item in items" :key="item.label">
        <RouterLink class="bottom-nav__link" :to="item.to">
          <span class="bottom-nav__icon">
            <component :is="item.icon" aria-hidden="true" />
            <NavBadge class="bottom-nav__badge" :count="item.count ?? 0" :label="item.badge ?? ''" />
          </span>
          <span class="bottom-nav__label">{{ item.label }}</span>
        </RouterLink>
      </li>
    </ul>
  </nav>
</template>

<style lang="scss" scoped>
.bottom-nav {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: $z-nav;
  padding-bottom: env(safe-area-inset-bottom);
  background: $color-surface;
  border-top: 1px solid $color-border;

  &__list {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    height: $bottom-nav-height;
    margin: 0;
  }

  &__link {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.15rem;
    height: 100%;
    color: $color-text-muted;
    font-size: 0.6875rem;
    font-weight: 600;

    &:hover {
      text-decoration: none;
    }

    &.router-link-active {
      color: $color-brand;
      box-shadow: inset 0 3px 0 $color-brand;
    }
  }

  &__icon {
    position: relative;

    svg {
      width: 1.4rem;
      height: 1.4rem;
    }
  }

  &__badge {
    position: absolute;
    top: -0.3rem;
    right: -0.7rem;
    box-shadow: 0 0 0 2px $color-surface;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .bottom-nav {
    display: none;
  }
}
</style>
