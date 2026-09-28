<script setup>
import { computed } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import NavBadge from '@/components/layout/NavBadge.vue'
import { useAuthStore } from '@/stores/auth'
import { useNotificationsStore } from '@/stores/notifications'
import { useMessagesStore } from '@/stores/messages'
import { useFriendsStore } from '@/stores/friends'
import { useEventsStore } from '@/stores/events'
import { fullName } from '@/utils/text'

// STORES
const auth = useAuthStore()
const notifications = useNotificationsStore()
const messages = useMessagesStore()
const friends = useFriendsStore()
const events = useEventsStore()

// COMPUTED
// Text-first navigation: no icon wall, just what matters and its pending count.
const links = computed(() => [
  { to: { name: 'home' }, label: 'Inicio', count: notifications.total, badge: 'novedades' },
  { to: { name: 'profile', params: { id: auth.meId } }, label: 'Perfil' },
  { to: { name: 'friends' }, label: 'Amigos', count: friends.incomingCount, badge: 'solicitudes pendientes' },
  { to: { name: 'photos' }, label: 'Fotos' },
  { to: { name: 'events' }, label: 'Eventos', count: events.pendingCount, badge: 'invitaciones pendientes' },
  { to: { name: 'messages' }, label: 'Mensajes', count: messages.unreadTotal, badge: 'conversaciones sin leer' },
])
</script>

<template>
  <nav class="sidenav" aria-label="Navegación principal">
    <RouterLink v-if="auth.me" class="sidenav__me" :to="{ name: 'profile', params: { id: auth.meId } }">
      <UserAvatar :person="auth.me" size="lg" />
      <span class="sidenav__me-text">
        <span class="sidenav__name">{{ fullName(auth.me) }}</span>
        <span class="sidenav__sub">Ver mi perfil</span>
      </span>
    </RouterLink>

    <ul class="sidenav__list" role="list">
      <li v-for="link in links" :key="link.label">
        <RouterLink class="sidenav__link" :to="link.to">
          <span>{{ link.label }}</span>
          <NavBadge :count="link.count ?? 0" :label="link.badge ?? ''" />
        </RouterLink>
      </li>
    </ul>

    <RouterLink class="sidenav__secondary" :to="{ name: 'settings' }">Configuración</RouterLink>
  </nav>
</template>

<style lang="scss" scoped>
.sidenav {
  position: sticky;
  top: calc(#{$header-height} + env(safe-area-inset-top) + #{$space-5});
  display: flex;
  flex-direction: column;
  gap: $space-4;

  &__me {
    display: flex;
    align-items: center;
    gap: $space-3;
    color: $color-text;

    &:hover {
      text-decoration: none;

      .sidenav__sub {
        text-decoration: underline;
      }
    }
  }

  &__me-text {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  &__name {
    @include truncate;
    font-weight: 700;
    color: $color-brand-strong;
  }

  &__sub {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__list {
    display: flex;
    flex-direction: column;
    gap: 1px;
    margin: 0;
  }

  &__link {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: $space-2;
    padding: 0.45rem $space-3;
    border-left: 3px solid transparent;
    border-radius: 0 $radius-sm $radius-sm 0;
    color: $color-text;
    font-weight: 600;

    &:hover {
      background: $color-surface-hover;
      text-decoration: none;
    }

    &.router-link-active {
      border-left-color: $color-brand;
      background: $color-surface;
      color: $color-brand-strong;
    }
  }

  &__secondary {
    padding: 0 $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
