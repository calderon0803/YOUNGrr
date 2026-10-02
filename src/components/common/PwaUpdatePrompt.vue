<script setup>
import { ref } from 'vue'
import { useRegisterSW } from 'virtual:pwa-register/vue'
import { PWA_RELOAD_FALLBACK_MS } from '@/config/app'

// DATA
// Registers the service worker; with registerType "prompt" we ask before updating.
// An installed app (above all on iPhone) comes back without reloading: look for
// a new version each time it is shown again.
const { needRefresh, updateServiceWorker } = useRegisterSW({
  immediate: true,
  onRegisteredSW(url, registration) {
    if (!registration) return
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') registration.update().catch(() => {})
    })
  },
})
const updating = ref(false)

// METHODS
const dismiss = () => {
  needRefresh.value = false
}

// The plugin only reloads when a version controlled the page at registration;
// after a hard reload (Ctrl+F5) none does, so the button seemed to do nothing,
// and an uncontrolled page never gets "controllerchange" either. So: reload as
// soon as the new version takes control, and in any case shortly after.
const update = async () => {
  if (updating.value) return
  updating.value = true
  let reloaded = false
  const reload = () => {
    if (reloaded) return
    reloaded = true
    window.location.reload()
  }
  navigator.serviceWorker?.addEventListener('controllerchange', reload, { once: true })
  setTimeout(reload, PWA_RELOAD_FALLBACK_MS)
  await updateServiceWorker(true)
}
</script>

<template>
  <Transition name="pwa">
    <div v-if="needRefresh" class="pwa" role="status">
      <p class="pwa__text">
        Hay una nueva versión de YOUNGrr.
      </p>
      <div class="pwa__actions">
        <button type="button" class="btn btn--primary btn--sm" :disabled="updating" @click="update">
          {{ updating ? 'Actualizando…' : 'Actualizar' }}
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
