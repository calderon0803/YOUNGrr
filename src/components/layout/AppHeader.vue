<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Search } from 'lucide-vue-next'
import AppLogo from '@/components/common/AppLogo.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import NavBadge from '@/components/layout/NavBadge.vue'
import { useAuthStore } from '@/stores/auth'
import { useNotificationsStore } from '@/stores/notifications'
import { useFriendsStore } from '@/stores/friends'
import { useEventsStore } from '@/stores/events'
import { useModerationStore } from '@/stores/moderation'

// Tuenti-style top bar: logo, section tabs and search. Your profile is the
// avatar; messages are the chat dock. On mobile the tabs move to the bottom
// navigation.

// STORES
const auth = useAuthStore()
const notifications = useNotificationsStore()
const friends = useFriendsStore()
const events = useEventsStore()
const moderation = useModerationStore()
const route = useRoute()
const router = useRouter()

// DATA
const query = ref('')
// "Moderación" only for moderators (the page and the data are protected anyway).
const accountMenu = computed(() => [
  { key: 'settings', label: 'Configuración' },
  ...(moderation.isModerator ? [{ key: 'moderation', label: 'Moderación' }] : []),
  { key: 'terms', label: 'Condiciones de uso' },
  { key: 'privacy', label: 'Privacidad' },
  { key: 'logout', label: 'Salir' },
])

// COMPUTED
const tabs = computed(() => [
  { to: { name: 'home' }, label: 'Inicio', count: notifications.total, badge: 'novedades', match: ['home'] },
  { to: { name: 'friends' }, label: 'Amigos', count: friends.incomingCount, badge: 'solicitudes pendientes', match: ['friends'] },
  { to: { name: 'events' }, label: 'Eventos', count: events.pendingCount, badge: 'invitaciones pendientes', match: ['events', 'event'] },
])

// METHODS
const isActive = (tab) => tab.match.includes(route.name)

const submitSearch = () => {
  router.push({ name: 'search', query: query.value.trim() ? { q: query.value.trim() } : {} })
}

const onAccountMenu = (key) => {
  if (key === 'settings') router.push({ name: 'settings' })
  else if (key === 'moderation') router.push({ name: 'moderation' })
  else if (key === 'terms' || key === 'privacy') router.push({ name: key })
  else auth.logout()
}

// WATCHERS
watch(
  () => route.query.q,
  (q) => (query.value = typeof q === 'string' ? q : ''),
  { immediate: true },
)
</script>

<template>
  <header class="header">
    <div class="header__inner">
      <RouterLink class="header__brand" :to="{ name: 'home' }" aria-label="YOUNGrr, ir a Inicio">
        <AppLogo on-dark size="md" />
      </RouterLink>

      <nav class="header__tabs" aria-label="Navegación principal">
        <ul class="header__tab-list" role="list">
          <li v-for="tab in tabs" :key="tab.label">
            <RouterLink
              class="header__tab"
              :class="{ 'header__tab--active': isActive(tab) }"
              :to="tab.to"
              :aria-current="isActive(tab) ? 'page' : undefined"
            >
              {{ tab.label }}
              <NavBadge :count="tab.count ?? 0" :label="tab.badge ?? ''" />
            </RouterLink>
          </li>
        </ul>
      </nav>

      <form class="header__search" role="search" @submit.prevent="submitSearch">
        <label class="visually-hidden" for="header-search">Buscar personas, eventos y álbumes</label>
        <Search class="header__search-icon" aria-hidden="true" />
        <input id="header-search" v-model="query" class="header__search-input" type="search" placeholder="Buscar" autocomplete="off" enterkeyhint="search" />
      </form>

      <div class="header__actions">
        <RouterLink class="header__icon" :to="{ name: 'search' }" aria-label="Buscar">
          <Search aria-hidden="true" />
        </RouterLink>
        <RouterLink v-if="auth.me" class="header__me" :to="{ name: 'profile', params: { id: auth.meId } }" :aria-label="`Tu perfil, ${auth.me.firstName}`">
          <UserAvatar :person="auth.me" size="xs" />
        </RouterLink>
        <DropdownMenu class="header__menu" on-dark label="Menú de la cuenta" :items="accountMenu" @select="onAccountMenu" />
      </div>
    </div>
  </header>
</template>

<style lang="scss" scoped>
.header {
  position: sticky;
  top: 0;
  z-index: $z-header;
  padding-top: env(safe-area-inset-top);
  background: $color-header-bg;
  color: $color-on-brand;

  &__inner {
    display: flex;
    align-items: center;
    gap: $space-3;
    max-width: $content-max;
    height: $header-height;
    margin: 0 auto;
    padding: 0 $space-3;
  }

  &__brand {
    display: flex;
    align-items: center;
    padding: $space-1;
    border-radius: $radius-sm;

    &:hover {
      text-decoration: none;
    }
  }

  &__tabs,
  &__search,
  &__me,
  &__menu {
    display: none;
  }

  &__tab-list {
    display: flex;
    align-items: flex-end;
    gap: 2px;
    height: 100%;
    margin: 0;
  }

  &__tab {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    height: 2.25rem;
    padding: 0 $space-3;
    border-radius: $radius $radius 0 0;
    color: $color-on-brand;
    font-weight: 600;

    &:hover {
      background: $color-header-hover;
      text-decoration: none;
    }

    // The active tab joins the page below it, like Tuenti's.
    &--active,
    &--active:hover {
      background: $color-bg;
      color: $color-brand-strong;
    }
  }

  &__search {
    position: relative;
  }

  &__search-icon {
    position: absolute;
    top: 50%;
    left: $space-2;
    width: 0.9rem;
    height: 0.9rem;
    color: $color-on-brand-muted;
    transform: translateY(-50%);
  }

  &__search-input {
    width: 11rem;
    height: 1.875rem;
    padding: 0 $space-2 0 1.75rem;
    border: 1px solid transparent;
    border-radius: $radius-sm;
    background: $color-header-hover;
    color: $color-on-brand;
    font-size: $fs-sm;

    &::placeholder {
      color: $color-on-brand-muted;
    }

    &:focus-visible {
      outline: 2px solid $color-on-brand;
      outline-offset: 1px;
      background: $color-surface;
      color: $color-text;
    }
  }

  &__actions {
    display: flex;
    align-items: center;
    gap: $space-1;
    margin-left: auto;
  }

  &__icon {
    display: grid;
    place-items: center;
    width: 2.25rem;
    height: 2.25rem;
    border-radius: $radius;
    color: $color-on-brand;

    svg {
      width: 1.25rem;
      height: 1.25rem;
    }

    &:hover {
      background: $color-header-hover;
    }
  }

  &__me {
    align-items: center;
    padding: 0.2rem;
    border-radius: $radius-sm;

    &:hover {
      background: $color-header-hover;
    }
  }

  :deep(.header__menu .dropdown__trigger:hover) {
    background: $color-header-hover;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .header {
    &__inner {
      align-items: stretch;
      gap: $space-4;
    }

    &__brand {
      align-self: center;
    }

    &__tabs {
      display: block;
      align-self: stretch;
    }

    &__actions {
      align-self: center;
    }

    &__me,
    &__menu {
      display: flex;
    }
  }
}

@media (min-width: $bp-desktop) {
  .header {
    &__search {
      display: block;
      align-self: center;
      margin-left: auto;
    }

    &__actions {
      margin-left: 0;
    }

    &__icon {
      display: none;
    }
  }
}
</style>
