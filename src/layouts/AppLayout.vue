<script setup>
import { defineAsyncComponent, onBeforeUnmount, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/components/layout/AppHeader.vue'
import SideNav from '@/components/layout/SideNav.vue'
import BottomNav from '@/components/layout/BottomNav.vue'
import { useNotificationsStore } from '@/stores/notifications'
import { useMessagesStore } from '@/stores/messages'
import { useFriendsStore } from '@/stores/friends'
import { useEventsStore } from '@/stores/events'
import { usePhotosStore } from '@/stores/photos'
import { useUserStore } from '@/stores/user'
import { BADGE_POLL_INTERVAL_MS } from '@/config/app'

const PhotoViewer = defineAsyncComponent(() => import('@/components/photos/PhotoViewer.vue'))

// STORES
const notifications = useNotificationsStore()
const route = useRoute()
const messages = useMessagesStore()
const friends = useFriendsStore()
const events = useEventsStore()
const photos = usePhotosStore()
const user = useUserStore()

// DATA
let poll = null

// METHODS
const refreshBadges = () => {
  notifications.loadSummary()
  messages.refreshUnread()
}

const onVisibility = () => {
  if (document.visibilityState === 'visible') refreshBadges()
}

// LIFECYCLE
onMounted(() => {
  refreshBadges()
  friends.loadRequests()
  events.loadEvents()
  user.loadSettings().catch(() => {})
  poll = setInterval(refreshBadges, BADGE_POLL_INTERVAL_MS)
  document.addEventListener('visibilitychange', onVisibility)
})

onBeforeUnmount(() => {
  clearInterval(poll)
  document.removeEventListener('visibilitychange', onVisibility)
})

// WATCHERS
// Pending counters change as you answer things around the app.
watch(() => route.fullPath, refreshBadges)
</script>

<template>
  <a class="skip-link" href="#main">Saltar al contenido</a>
  <AppHeader />
  <div class="shell">
    <aside class="shell__nav">
      <SideNav />
    </aside>
    <main id="main" class="shell__main" tabindex="-1">
      <slot />
    </main>
  </div>
  <BottomNav />
  <PhotoViewer v-if="photos.viewer.open" />
</template>

<style lang="scss" scoped>
.shell {
  max-width: $content-max;
  margin: 0 auto;
  padding: $space-3 0 calc(#{$bottom-nav-height} + env(safe-area-inset-bottom) + #{$space-6});

  &__nav {
    display: none;
  }

  &__main {
    min-width: 0;
    outline: none;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .shell {
    display: grid;
    grid-template-columns: 11.5rem minmax(0, 1fr);
    align-items: start;
    gap: $space-5;
    padding: $space-5 $space-5 $space-10;

    &__nav {
      display: block;
    }
  }
}

@media (min-width: $bp-desktop) {
  .shell {
    grid-template-columns: 13.5rem minmax(0, 1fr);
    gap: $space-6;
  }
}
</style>
