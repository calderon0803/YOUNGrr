<script setup>
import { ref } from 'vue'
import { WifiOff } from 'lucide-vue-next'
import AppLogo from '@/components/common/AppLogo.vue'

// YOUNGrr has no offline mode: without a connection nothing can be used.

// DATA
const checking = ref(false)

// METHODS
// Reload so the session and data are fetched again from the backend.
const retry = () => {
  checking.value = true
  if (navigator.onLine) window.location.reload()
  else setTimeout(() => (checking.value = false), 600)
}
</script>

<template>
  <main class="offline" role="alert">
    <AppLogo size="lg" />
    <WifiOff class="offline__icon" aria-hidden="true" />
    <h1 class="offline__title">No hay conexión a internet</h1>
    <p class="offline__text">YOUNGrr necesita conexión para entrar y ver lo que hacen tus amigos. Comprueba tu Wi-Fi o tus datos móviles.</p>
    <button type="button" class="btn btn--primary" :disabled="checking" @click="retry">
      {{ checking ? 'Comprobando…' : 'Reintentar' }}
    </button>
  </main>
</template>

<style lang="scss" scoped>
.offline {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: $space-3;
  min-height: 100dvh;
  padding: calc(#{$space-6} + env(safe-area-inset-top)) $space-6 calc(#{$space-6} + env(safe-area-inset-bottom));
  background: $color-bg;
  text-align: center;

  &__icon {
    width: 2.25rem;
    height: 2.25rem;
    margin-top: $space-6;
    color: $color-text-soft;
  }

  &__title {
    font-size: $fs-lg;
    font-weight: 800;
  }

  &__text {
    max-width: 24rem;
    margin-bottom: $space-2;
    color: $color-text-muted;
  }
}
</style>
