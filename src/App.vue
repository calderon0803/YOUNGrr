<script setup>
import { computed, onBeforeUnmount, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppLayout from '@/layouts/AppLayout.vue'
import AuthLayout from '@/layouts/AuthLayout.vue'
import ToastHost from '@/components/common/ToastHost.vue'
import ConfirmHost from '@/components/common/ConfirmHost.vue'
import PwaUpdatePrompt from '@/components/common/PwaUpdatePrompt.vue'
import OfflineScreen from '@/components/common/OfflineScreen.vue'
import { useOnline } from '@/composables/useOnline'
import { useAuthStore } from '@/stores/auth'
import { SETUP_REQUIRED_EVENT } from '@/config/app'

// STORES
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

// DATA
const online = useOnline()

// COMPUTED
// Public pages (the legal texts) open inside the app once the account is ready.
const layout = computed(() => (route.meta.layout === 'auth' || !auth.isAuthenticated || (route.meta.public && auth.needsSetup) ? AuthLayout : AppLayout))

// METHODS
// The database asked to complete the account (e.g. new terms while the app was
// open): reload the profile and go to the setup page, once at a time.
let checking = false
const onSetupRequired = async () => {
  if (checking) return
  checking = true
  await auth.refresh()
  checking = false
  if (auth.needsSetup && route.name !== 'setup') router.replace({ name: 'setup' })
}

// LIFECYCLE
onMounted(() => window.addEventListener(SETUP_REQUIRED_EVENT, onSetupRequired))
onBeforeUnmount(() => window.removeEventListener(SETUP_REQUIRED_EVENT, onSetupRequired))
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
