<script setup>
import { ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { MessageCircle, Search } from 'lucide-vue-next'
import AppLogo from '@/components/common/AppLogo.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import NavBadge from '@/components/layout/NavBadge.vue'
import { useAuthStore } from '@/stores/auth'
import { useMessagesStore } from '@/stores/messages'

// STORES
const auth = useAuthStore()
const messages = useMessagesStore()
const route = useRoute()
const router = useRouter()

// DATA
const query = ref('')
const ACCOUNT_MENU = [
  { key: 'profile', label: 'Mi perfil' },
  { key: 'settings', label: 'Configuración' },
  { key: 'logout', label: 'Salir' },
]

// METHODS
const submitSearch = () => {
  router.push({ name: 'search', query: query.value.trim() ? { q: query.value.trim() } : {} })
}

const onAccountMenu = (key) => {
  if (key === 'profile') router.push({ name: 'profile', params: { id: auth.meId } })
  else if (key === 'settings') router.push({ name: 'settings' })
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

      <form class="header__search" role="search" @submit.prevent="submitSearch">
        <label class="visually-hidden" for="header-search">Buscar personas, eventos y álbumes</label>
        <Search class="header__search-icon" aria-hidden="true" />
        <input
          id="header-search"
          v-model="query"
          class="header__search-input"
          type="search"
          placeholder="Buscar personas, eventos, álbumes"
          autocomplete="off"
          enterkeyhint="search"
        />
      </form>

      <nav class="header__actions" aria-label="Accesos rápidos">
        <RouterLink class="header__icon header__icon--search" :to="{ name: 'search' }" aria-label="Buscar">
          <Search aria-hidden="true" />
        </RouterLink>
        <RouterLink class="header__icon header__icon--messages" :to="{ name: 'messages' }" aria-label="Mensajes">
          <MessageCircle aria-hidden="true" />
          <NavBadge class="header__badge" :count="messages.unreadTotal" label="conversaciones sin leer" />
        </RouterLink>

        <RouterLink v-if="auth.me" class="header__me" :to="{ name: 'profile', params: { id: auth.meId } }">
          <UserAvatar :person="auth.me" size="xs" />
          <span>{{ auth.me.firstName }}</span>
        </RouterLink>
        <DropdownMenu class="header__menu" on-dark label="Menú de la cuenta" :items="ACCOUNT_MENU" @select="onAccountMenu" />
      </nav>
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

  &__search {
    display: none;
  }

  &__actions {
    display: flex;
    align-items: center;
    gap: $space-1;
    margin-left: auto;
  }

  &__icon {
    position: relative;
    display: grid;
    place-items: center;
    width: 2.5rem;
    height: 2.5rem;
    border-radius: $radius;
    color: $color-on-brand;

    svg {
      width: 1.35rem;
      height: 1.35rem;
    }

    &:hover,
    &.router-link-active {
      background: $color-header-hover;
    }

    &--messages {
      display: none;
    }
  }

  &__badge {
    position: absolute;
    top: 0.2rem;
    right: 0.1rem;
    box-shadow: 0 0 0 2px $color-header-bg;
  }

  &__me,
  &__menu {
    display: none;
  }

  &__me {
    align-items: center;
    gap: $space-2;
    padding: $space-1 $space-2;
    border-radius: $radius;
    color: $color-on-brand;
    font-weight: 600;

    &:hover {
      background: $color-header-hover;
      text-decoration: none;
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
      gap: $space-5;
      padding: 0 $space-5;
    }

    &__search {
      position: relative;
      display: block;
      flex: 1;
      max-width: 24rem;
    }

    &__search-icon {
      position: absolute;
      top: 50%;
      left: $space-3;
      width: 1rem;
      height: 1rem;
      color: $color-on-brand-muted;
      transform: translateY(-50%);
    }

    &__search-input {
      width: 100%;
      height: 2.125rem;
      padding: 0 $space-3 0 2.25rem;
      border: 1px solid transparent;
      border-radius: $radius;
      background: $color-header-hover;
      color: $color-on-brand;

      &::placeholder {
        color: $color-on-brand-muted;
      }

      &:focus-visible {
        outline: 2px solid $color-on-brand;
        outline-offset: 1px;
        background: $color-surface;
        color: $color-text;

        &::placeholder {
          color: $color-text-soft;
        }
      }
    }

    &__icon {
      &--search {
        display: none;
      }

      &--messages {
        display: grid;
      }
    }

    &__me {
      display: flex;
    }

    &__menu {
      display: block;
    }
  }
}
</style>
