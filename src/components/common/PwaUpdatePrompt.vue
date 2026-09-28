<script setup>
import { useRegisterSW } from 'virtual:pwa-register/vue'

// DATA
// Registers the service worker; with registerType "prompt" we ask before updating.
const { needRefresh, updateServiceWorker } = useRegisterSW({ immediate: true })

// METHODS
const dismiss = () => {
  needRefresh.value = false
}
</script>

<template>
  <Transition name="pwa">
    <div v-if="needRefresh" class="pwa" role="status">
      <p class="pwa__text">
        Hay una nueva versión de YOUNGrr.
      </p>
      <div class="pwa__actions">
        <button type="button" class="btn btn--primary btn--sm" @click="updateServiceWorker(true)">
          Actualizar
        </button>
        <button type="button" class="btn btn--ghost btn--sm" @click="dismiss">
          Más tarde
        </button>
      </div>
    </div>
  </Transition>
</template>

<style lang="scss" scoped>
.pwa {
  position: fixed;
  top: calc(#{$header-height} + env(safe-area-inset-top) + #{$space-2});
  left: 50%;
  z-index: $z-toast;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: $space-3;
  width: calc(100% - #{$space-6});
  max-width: 28rem;
  padding: $space-3 $space-4;
  background: $color-surface;
  border: 1px solid $color-border-strong;
  border-radius: $radius;
  box-shadow: 0 6px 18px $color-shadow;
  transform: translateX(-50%);

  &__text {
    flex: 1;
    font-weight: 600;
  }

  &__actions {
    display: flex;
    gap: $space-2;
  }
}

.pwa-enter-active,
.pwa-leave-active {
  transition: opacity $duration;
}

.pwa-enter-from,
.pwa-leave-to {
  opacity: 0;
}
</style>
