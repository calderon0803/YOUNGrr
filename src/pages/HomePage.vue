<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { MapPin, Users } from 'lucide-vue-next'
import PostComposer from '@/components/feed/PostComposer.vue'
import PostList from '@/components/feed/PostList.vue'
import NearbyRadius from '@/components/feed/NearbyRadius.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import TabNav from '@/components/common/TabNav.vue'
import ProfileEditDialog from '@/components/profile/ProfileEditDialog.vue'
import NotificationSummary from '@/components/notifications/NotificationSummary.vue'
import SuggestionsWidget from '@/components/friends/SuggestionsWidget.vue'
import UpcomingEventsWidget from '@/components/events/UpcomingEventsWidget.vue'
import { useFeedStore } from '@/stores/feed'
import { useAuthStore } from '@/stores/auth'
import { useUserStore } from '@/stores/user'
import { NEARBY_DEFAULT_RADIUS_KM } from '@/config/app'

// STORES
const route = useRoute()
const feed = useFeedStore()
const auth = useAuthStore()
const user = useUserStore()

// DATA
const TABS = [
  { key: 'friends', label: 'Amigos' },
  { key: 'nearby', label: 'Cerca de ti' },
]
const editingLocation = ref(false)

// COMPUTED
const tab = computed(() => (route.query.feed === 'nearby' ? 'nearby' : 'friends'))
const hasFriends = computed(() => (user.profiles[auth.meId]?.data?.friendsCount ?? 1) > 0)
const radiusKm = computed(() => user.settings?.nearby?.radiusKm ?? NEARBY_DEFAULT_RADIUS_KM)
// Reload "Cerca de ti" when the user changes town.
const locationKey = computed(() => `${auth.me?.cityLat},${auth.me?.cityLng}`)

// METHODS
const tabRoute = (key) => ({ query: key === 'friends' ? {} : { feed: key } })

const load = () => {
  if (tab.value === 'friends') {
    if (feed.home.status !== 'success' || feed.home.stale) feed.loadFeed()
  } else if (feed.nearby.status !== 'success' || feed.nearby.stale || feed.nearby.radiusKm !== radiusKm.value) {
    feed.loadNearby(radiusKm.value)
  }
}

const changeRadius = async (km) => {
  await user.setNearbyRadius(km)
  feed.loadNearby(km)
}

// LIFECYCLE
user.loadProfile(auth.meId, { silent: true })

// WATCHERS
watch(tab, load, { immediate: true })
watch(radiusKm, () => tab.value === 'nearby' && load())
watch(locationKey, () => {
  feed.nearby.stale = true
  if (tab.value === 'nearby') load()
})
</script>

<template>
  <div class="home">
    <div class="home__main">
      <h1 class="visually-hidden">Inicio</h1>
      <NotificationSummary class="home__summary" />
      <PostComposer />

      <div class="panel home__switch">
        <TabNav label="Qué publicaciones ver" :tabs="TABS" :active="tab" :to="tabRoute" />
        <NearbyRadius
          v-if="tab === 'nearby' && !feed.nearby.needsLocation"
          :model-value="radiusKm"
          :city="feed.nearby.originCity || auth.me?.city"
          :disabled="feed.nearby.status === 'loading'"
          @update:model-value="changeRadius"
        />
      </div>

      <PostList v-if="tab === 'friends'" :list="feed.home" @retry="feed.loadFeed()" @more="feed.loadFeed({ more: true })">
        <template #empty>
          <div class="panel">
            <StateMessage
              v-if="!hasFriends"
              :icon="Users"
              title="Todavía no tienes amigos."
              text="Busca personas para empezar. Aquí verás lo que publican."
            >
              <RouterLink class="btn btn--primary" :to="{ name: 'friends', query: { tab: 'search' } }">Buscar personas</RouterLink>
            </StateMessage>
            <StateMessage v-else title="Todavía no hay publicaciones." text="Cuando tus amigos publiquen algo, aparecerá aquí. Puedes empezar tú." />
          </div>
        </template>
      </PostList>

      <PostList
        v-else
        :list="feed.nearby"
        :meta="feed.nearby.meta"
        @retry="feed.loadNearby(radiusKm)"
        @more="feed.loadNearby(radiusKm, { more: true })"
      >
        <template #empty>
          <div class="panel">
            <StateMessage
              v-if="feed.nearby.needsLocation"
              :icon="MapPin"
              title="Indica dónde vives."
              text="Añade tu ciudad o pueblo a tu perfil para ver lo que publica la gente de tu zona."
            >
              <button type="button" class="btn btn--primary" @click="editingLocation = true">Añadir ciudad o pueblo</button>
            </StateMessage>
            <StateMessage
              v-else
              :icon="MapPin"
              :title="`Nadie ha publicado a menos de ${radiusKm} km.`"
              text="Solo aparecen las cuentas públicas de tu zona y las de tus amigos. Prueba con un radio mayor."
            />
          </div>
        </template>
      </PostList>

      <ProfileEditDialog v-if="auth.me" :open="editingLocation" :profile="auth.me" @close="editingLocation = false" />
    </div>
    <aside class="home__rail" aria-label="Resumen">
      <NotificationSummary />
      <UpcomingEventsWidget />
      <SuggestionsWidget />
    </aside>
  </div>
</template>

<style lang="scss" scoped>
.home {
  display: grid;
  gap: $space-4;

  &__main {
    display: flex;
    flex-direction: column;
    gap: $space-3;
    min-width: 0;
  }

  &__switch {
    overflow: hidden;
    border-radius: 0;
    border-right: 0;
    border-left: 0;

    :deep(.tabs) {
      border-bottom: 0;
    }

    :deep(.radius) {
      border-top: 1px solid $color-border;
    }
  }

  &__rail {
    display: none;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .home__switch {
    border-right: 1px solid $color-border;
    border-left: 1px solid $color-border;
    border-radius: $radius;
  }
}

@media (min-width: $bp-desktop) {
  .home {
    grid-template-columns: minmax(0, 1fr) 18.5rem;
    align-items: start;
    gap: $space-6;

    &__summary {
      display: none;
    }

    &__rail {
      position: sticky;
      top: calc(#{$header-height} + #{$space-5});
      display: flex;
      flex-direction: column;
      gap: $space-4;
    }
  }
}
</style>
