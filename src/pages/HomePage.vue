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
import BirthdaysWidget from '@/components/friends/BirthdaysWidget.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import UpcomingEventsWidget from '@/components/events/UpcomingEventsWidget.vue'
import { useFeedStore } from '@/stores/feed'
import { useAuthStore } from '@/stores/auth'
import { useUserStore } from '@/stores/user'
import { NEARBY_DEFAULT_RADIUS_KM } from '@/config/app'
import { fullName } from '@/utils/text'

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
const myStatus = computed(() => user.profiles[auth.meId]?.data?.status ?? null)
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

// A text-only post is your new status.
const onPublished = () => user.loadProfile(auth.meId, { silent: true })

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
    <h1 class="visually-hidden">Inicio</h1>

    <aside class="home__left" aria-label="Tu estado y tus novedades">
      <RouterLink v-if="auth.me" class="home__me panel" :to="{ name: 'profile', params: { id: auth.meId } }">
        <UserAvatar :person="auth.me" size="lg" />
        <span class="home__me-text">
          <strong>{{ fullName(auth.me) }}</strong>
          <span>Ver mi perfil</span>
        </span>
      </RouterLink>
      <PostComposer :status="myStatus" @published="onPublished" />
      <NotificationSummary />
    </aside>

    <section class="home__center panel" aria-labelledby="feed-title">
      <h2 id="feed-title" class="panel-title">Novedades de tus amigos</h2>
      <TabNav class="home__tabs" label="Qué novedades ver" :tabs="TABS" :active="tab" :to="tabRoute" />
      <NearbyRadius
        v-if="tab === 'nearby' && !feed.nearby.needsLocation"
        class="home__radius"
        :model-value="radiusKm"
        :city="feed.nearby.originCity || auth.me?.city"
        :disabled="feed.nearby.status === 'loading'"
        @update:model-value="changeRadius"
      />

      <PostList v-if="tab === 'friends'" :list="feed.home" @retry="feed.loadFeed()" @more="feed.loadFeed({ more: true })">
        <template #empty>
          <StateMessage
            v-if="!hasFriends"
            :icon="Users"
            title="Todavía no tienes amigos."
            text="Busca personas para empezar. Aquí verás lo que publican."
          >
            <RouterLink class="btn btn--primary" :to="{ name: 'friends', query: { tab: 'search' } }">Buscar personas</RouterLink>
          </StateMessage>
          <StateMessage v-else title="Todavía no hay novedades." text="Cuando tus amigos publiquen algo, aparecerá aquí. Puedes empezar tú." />
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
        </template>
      </PostList>
    </section>

    <aside class="home__right" aria-label="Planes y cumpleaños">
      <UpcomingEventsWidget />
      <BirthdaysWidget />
      <SuggestionsWidget />
    </aside>

    <ProfileEditDialog v-if="auth.me" :open="editingLocation" :profile="auth.me" @close="editingLocation = false" />
  </div>
</template>

<style lang="scss" scoped>
.home {
  display: flex;
  flex-direction: column;
  gap: $space-3;

  &__left,
  &__right {
    display: flex;
    flex-direction: column;
    gap: $space-3;
    min-width: 0;
  }

  &__me {
    display: none;
    align-items: center;
    gap: $space-3;
    padding: $space-3;
    color: $color-text;

    &:hover {
      text-decoration: none;

      span span {
        text-decoration: underline;
      }
    }
  }

  &__me-text {
    display: flex;
    flex-direction: column;
    min-width: 0;

    strong {
      color: $color-brand-strong;
    }

    span {
      font-size: $fs-sm;
      color: $color-link;
    }
  }

  &__center {
    min-width: 0;
    overflow: hidden;
    border-radius: 0;
    border-right: 0;
    border-left: 0;
  }

  &__tabs {
    background: $color-surface-alt;
  }

  &__radius {
    border-bottom: 1px solid $color-border;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .home {
    display: grid;
    grid-template-columns: 15rem minmax(0, 1fr);
    grid-template-areas:
      'left center'
      'right center';
    align-items: start;
    gap: $space-4;

    &__left {
      grid-area: left;
    }

    &__right {
      grid-area: right;
    }

    &__center {
      grid-area: center;
      border-right: 1px solid $color-border;
      border-left: 1px solid $color-border;
      border-radius: $radius;
    }

    &__me {
      display: flex;
    }
  }
}

@media (min-width: $bp-desktop) {
  .home {
    grid-template-columns: 15rem minmax(0, 1fr) 14.5rem;
    grid-template-areas: 'left center right';
  }
}
</style>
