<script setup>
import { computed } from 'vue'
import StateMessage from '@/components/common/StateMessage.vue'
import { useAuthStore } from '@/stores/auth'

// STORES
const auth = useAuthStore()

// COMPUTED
const home = computed(() => (auth.isAuthenticated ? { name: 'home' } : '/'))
</script>

<template>
  <div class="panel not-found">
    <p class="not-found__code" aria-hidden="true">404</p>
    <StateMessage title="Esta página no existe." text="Puede que el enlace esté mal escrito o que el contenido se haya eliminado.">
      <RouterLink class="btn btn--primary" :to="home">Volver al inicio</RouterLink>
    </StateMessage>
  </div>
</template>

<style lang="scss" scoped>
.not-found {
  max-width: 32rem;
  margin: $space-8 auto;
  text-align: center;

  &__code {
    padding-top: $space-6;
    font-family: $font-display;
    font-size: 4rem;
    font-weight: 800;
    color: $color-brand-soft;
  }
}
</style>
