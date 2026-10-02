<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { Lock } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import TabNav from '@/components/common/TabNav.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import ProfileAside from '@/components/profile/ProfileAside.vue'
import ProfileWall from '@/components/profile/ProfileWall.vue'
import ProfileEditDialog from '@/components/profile/ProfileEditDialog.vue'
import ProfilePhotos from '@/components/profile/ProfilePhotos.vue'
import ProfileTaggedPhotos from '@/components/profile/ProfileTaggedPhotos.vue'
import ProfileAlbums from '@/components/profile/ProfileAlbums.vue'
import ProfileTastes from '@/components/tastes/ProfileTastes.vue'
import ProfileFriends from '@/components/profile/ProfileFriends.vue'
import LevelBadge from '@/components/levels/LevelBadge.vue'
import SpotifyCard from '@/components/feed/SpotifyCard.vue'
import { useUserStore } from '@/stores/user'
import { useNotificationsStore } from '@/stores/notifications'
import { useXpStore } from '@/stores/xp'
import { fullName } from '@/utils/text'
import { withoutSpotifyLink } from '@/utils/spotify'

// Tuenti-style profile: details on the left; name, current status and the wall
// (tablón) on the right, with the rest in tabs.

// STORES
const route = useRoute()
const user = useUserStore()
const notifications = useNotificationsStore()
const xp = useXpStore()

// DATA
const editing = ref(false)
const TAB_KEYS = ['wall', 'photos', 'tagged', 'albums', 'tastes', 'friends']
const TABS = [
  { key: 'wall', label: 'Tablón' },
  { key: 'photos', label: 'Fotos' },
  { key: 'tagged', label: 'Etiquetas' },
  { key: 'albums', label: 'Álbumes' },
  { key: 'tastes', label: 'Gustos' },
  { key: 'friends', label: 'Amigos' },
]
// Your own tabs clear the home counters they cover.
const SEEN_LIST = { wall: 'wall', photos: 'photos', tagged: 'tagged', friends: 'friends' }

// COMPUTED
const userId = computed(() => String(route.params.id))
const state = computed(() => user.profiles[userId.value] ?? { status: 'loading', error: null, data: null })
const view = computed(() => state.value.data)
const isSelf = computed(() => view.value?.friendship === 'self')
// With a Spotify card, the link is not repeated in the text.
const statusText = computed(() => (view.value?.status ? withoutSpotifyLink(view.value.status.text, view.value.status.link) : ''))
const tab = computed(() => (TAB_KEYS.includes(route.query.tab) ? route.query.tab : 'wall'))

// METHODS
const tabRoute = (key) => ({ query: key === 'wall' ? {} : { tab: key } })

const loadTab = () => {
  if (isSelf.value && SEEN_LIST[tab.value]) notifications.markSeen({ list: SEEN_LIST[tab.value] })
}

// WATCHERS
watch(
  userId,
  async (id) => {
    await user.loadProfile(id, { silent: true })
    const self = user.profiles[id]?.data?.friendship === 'self'
    if (!self) user.registerVisit(id)
    xp.loadLevel(id)
    if (self && notifications.summary.groups.some((g) => g.key === 'level_up')) xp.markLevelSeen()
    loadTab()
  },
  { immediate: true },
)

watch(tab, loadTab)
</script>

<template>
  <div class="profile">
    <AsyncState :status="state.status" :error="state.error" skeleton="block" @retry="user.loadProfile(userId)">
      <template v-if="view">
        <ProfileAside :key="view.profile.id" class="profile__aside" :view="view" @edit="editing = true" />

        <div class="profile__main">
          <header class="profile__head panel">
            <h1 class="profile__name">
              {{ fullName(view.profile) }}
              <LevelBadge v-if="xp.levels[view.profile.id]" :level="xp.levels[view.profile.id]" />
            </h1>
            <p v-if="view.status" class="profile__status">
              <span v-if="statusText" class="user-text">{{ statusText }}</span>
              <RouterLink class="profile__status-time" :to="{ name: 'post', params: { id: view.status.postId } }">
                <RelativeTime :value="view.status.createdAt" />
              </RouterLink>
            </p>
            <SpotifyCard v-if="view.status?.link" :link="view.status.link" />
            <p v-else-if="isSelf && view.canViewProfile && !view.status" class="profile__status profile__status--empty">
              Todavía no has escrito tu estado. Hazlo desde
              <RouterLink :to="{ name: 'home' }">Inicio</RouterLink>.
            </p>
          </header>

          <div v-if="!view.canViewProfile" class="panel">
            <StateMessage
              :icon="Lock"
              :title="`El perfil de ${view.profile.firstName} es privado.`"
              :text="view.canSendRequest ? 'Solo sus amigos pueden verlo. Envíale una solicitud de amistad.' : 'Solo sus amigos pueden verlo.'"
            />
          </div>

          <section v-else class="profile__content panel" aria-label="Secciones del perfil">
            <TabNav class="profile__tabs" label="Secciones del perfil" :tabs="TABS" :active="tab" :to="tabRoute" />

            <ProfileWall v-if="tab === 'wall'" :view="view" />
            <ProfilePhotos v-else-if="tab === 'photos'" :view="view" />
            <ProfileTaggedPhotos v-else-if="tab === 'tagged'" :view="view" />
            <ProfileAlbums v-else-if="tab === 'albums'" :view="view" />
            <ProfileTastes v-else-if="tab === 'tastes'" :view="view" />
            <ProfileFriends v-else :view="view" />
          </section>
        </div>

        <ProfileEditDialog v-if="isSelf" :open="editing" :profile="view.profile" @close="editing = false" />
      </template>
    </AsyncState>
  </div>
</template>

<style lang="scss" scoped>
.profile {
  display: flex;
  flex-direction: column;
  gap: $space-3;

  &__main {
    order: 2;
    display: flex;
    flex-direction: column;
    gap: $space-3;
    min-width: 0;
  }

  &__head {
    padding: $space-3 $space-4;
  }

  &__name {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: $space-2;
    font-size: $fs-xl;
    font-weight: 800;
  }

  &__status {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0 $space-2;
    margin-top: $space-1;
    font-size: $fs-md;

    &--empty {
      font-size: $fs-sm;
      color: $color-text-muted;
    }
  }

  &__status-time {
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__content {
    overflow: hidden;
  }

  &__tabs {
    background: $color-surface-alt;
  }

  // The tabs' contents come as panels of their own; inside this block they are
  // flat, with the same margins in every tab (the tab names the section).
  &__content :deep(> .panel) {
    border: 0;
    border-radius: 0;
  }

  &__content :deep(.photo-grid),
  &__content :deep(.album-grid) {
    padding: $space-3 $space-4 $space-4;
  }

  &__content :deep(.person-grid) {
    margin-top: $space-2;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .profile {
    display: grid;
    grid-template-columns: 14.5rem minmax(0, 1fr);
    align-items: start;
    gap: $space-4;
  }
}
</style>
