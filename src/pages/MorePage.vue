<script setup>
import { ChevronRight } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import NavBadge from '@/components/layout/NavBadge.vue'
import { useAuthStore } from '@/stores/auth'
import { useEventsStore } from '@/stores/events'
import { fullName } from '@/utils/text'

// Mobile menu: everything that doesn't fit in the bottom navigation.

// STORES
const auth = useAuthStore()
const events = useEventsStore()
</script>

<template>
  <div class="more">
    <h1 class="visually-hidden">Más</h1>
    <RouterLink class="more__me panel" :to="{ name: 'profile', params: { id: auth.meId } }">
      <UserAvatar :person="auth.me" size="lg" />
      <span class="more__me-text">
        <strong>{{ fullName(auth.me) }}</strong>
        <span>Ver mi perfil</span>
      </span>
      <ChevronRight aria-hidden="true" />
    </RouterLink>

    <nav class="panel" aria-label="Más secciones">
      <ul class="more__list" role="list">
        <li>
          <RouterLink class="more__link" :to="{ name: 'events' }">
            Eventos <NavBadge :count="events.pendingCount" label="invitaciones pendientes" />
          </RouterLink>
        </li>
        <li><RouterLink class="more__link" :to="{ name: 'search' }">Buscar</RouterLink></li>
        <li><RouterLink class="more__link" :to="{ name: 'settings' }">Configuración</RouterLink></li>
        <li><RouterLink class="more__link" :to="{ name: 'terms' }">Condiciones de uso</RouterLink></li>
        <li><RouterLink class="more__link" :to="{ name: 'privacy' }">Privacidad</RouterLink></li>
      </ul>
    </nav>

    <button type="button" class="btn btn--secondary btn--block" @click="auth.logout()">Salir de YOUNGrr</button>
  </div>
</template>

<style lang="scss" scoped>
.more {
  display: flex;
  flex-direction: column;
  gap: $space-3;
  padding: 0 $space-3;

  &__me {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-3 $space-4;
    color: $color-text;

    &:hover {
      text-decoration: none;
    }

    svg {
      width: 1.2rem;
      height: 1.2rem;
      color: $color-text-soft;
    }
  }

  &__me-text {
    display: flex;
    flex: 1;
    flex-direction: column;

    span {
      font-size: $fs-sm;
      color: $color-text-muted;
    }
  }

  &__list {
    margin: 0;

    li + li {
      border-top: 1px solid $color-border;
    }
  }

  &__link {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: $space-4;
    color: $color-text;
    font-weight: 600;

    &:hover {
      background: $color-surface-hover;
      text-decoration: none;
    }
  }
}
</style>
