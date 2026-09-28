<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppLayout from '@/layouts/AppLayout.vue'
import AuthLayout from '@/layouts/AuthLayout.vue'
import ToastHost from '@/components/common/ToastHost.vue'
import ConfirmHost from '@/components/common/ConfirmHost.vue'
import PwaUpdatePrompt from '@/components/common/PwaUpdatePrompt.vue'
import OfflineScreen from '@/components/common/OfflineScreen.vue'
import { useOnline } from '@/composables/useOnline'
import { useAuthStore } from '@/stores/auth'

// STORES
const route = useRoute()
const auth = useAuthStore()

// DATA
const online = useOnline()

// COMPUTED
const layout = computed(() => (route.meta.layout === 'auth' || !auth.isAuthenticated ? AuthLayout : AppLayout))
</script>

<template>
  <OfflineScreen v-if="!online" />
  <component :is="layout" v-else-if="auth.ready && route.matched.length">
    <RouterView v-slot="{ Component }">
      <Transition name="page" mode="out-in">
        <component :is="Component" :key="route.path" />
      </Transition>
    </RouterView>
  </component>
  <div v-else class="boot" aria-busy="true">
    <span class="visually-hidden">Cargando YOUNGrr…</span>
  </div>
  <ToastHost />
  <ConfirmHost />
  <PwaUpdatePrompt />
</template>

<style lang="scss" scoped>
.boot {
  min-height: 100dvh;
  background: $color-bg;
}

.page-enter-active {
  transition:
    opacity 160ms $ease-out,
    transform 160ms $ease-out;
}

.page-leave-active {
  transition: opacity 90ms;
}

.page-enter-from {
  opacity: 0;
  transform: translateY(0.35rem);
}

.page-leave-to {
  opacity: 0;
}
</style>
