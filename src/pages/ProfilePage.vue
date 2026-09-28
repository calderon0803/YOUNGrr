<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { Lock, UserX } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import TabNav from '@/components/common/TabNav.vue'
import ProfileHeader from '@/components/profile/ProfileHeader.vue'
import ProfileInfo from '@/components/profile/ProfileInfo.vue'
import ProfileEditDialog from '@/components/profile/ProfileEditDialog.vue'
import ProfilePhotos from '@/components/profile/ProfilePhotos.vue'
import ProfileTaggedPhotos from '@/components/profile/ProfileTaggedPhotos.vue'
import ProfileAlbums from '@/components/profile/ProfileAlbums.vue'
import ProfileFriends from '@/components/profile/ProfileFriends.vue'
import PostComposer from '@/components/feed/PostComposer.vue'
import PostList from '@/components/feed/PostList.vue'
import { useUserStore } from '@/stores/user'
import { useFeedStore } from '@/stores/feed'
import { useNotificationsStore } from '@/stores/notifications'

// STORES
const route = useRoute()
const user = useUserStore()
const feed = useFeedStore()
const notifications = useNotificationsStore()

// DATA
const editing = ref(false)
const TAB_KEYS = ['posts', 'photos', 'tagged', 'albums', 'friends', 'info']

// COMPUTED
const userId = computed(() => String(route.params.id))
const state = computed(() => user.profiles[userId.value] ?? { status: 'loading', error: null, data: null })
const view = computed(() => state.value.data)
const isSelf = computed(() => view.value?.friendship === 'self')
const tab = computed(() => (TAB_KEYS.includes(route.query.tab) ? route.query.tab : 'posts'))
const timeline = computed(() => feed.timelines[userId.value] ?? { ids: [], status: 'loading', error: null, hasMore: false })

const tabs = computed(() => [
  { key: 'posts', label: 'Publicaciones' },
  { key: 'photos', label: 'Fotos' },
  { key: 'tagged', label: 'Etiquetas' },
  { key: 'albums', label: 'Álbumes' },
  { key: 'friends', label: 'Amigos' },
  { key: 'info', label: 'Información' },
])

// METHODS
const tabRoute = (key) => ({ query: key === 'posts' ? {} : { tab: key } })

// Your own tabs clear the home counters they cover.
const SEEN_LIST = { posts: 'posts', photos: 'photos', tagged: 'tagged', friends: 'friends' }

const loadTab = () => {
  if (isSelf.value && SEEN_LIST[tab.value]) notifications.markSeen({ list: SEEN_LIST[tab.value] })
  if (!view.value?.canViewProfile) return
  if (tab.value === 'posts') feed.loadTimeline(userId.value)
}

// WATCHERS
watch(
  userId,
  async (id) => {
    await user.loadProfile(id, { silent: true })
    if (user.profiles[id]?.data?.friendship !== 'self') user.registerVisit(id)
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
        <ProfileHeader :view="view" @edit="editing = true" />

        <div v-if="!view.canViewProfile" class="panel">
          <StateMessage
            :icon="Lock"
            :title="`El perfil de ${view.profile.firstName} es privado.`"
            :text="view.canSendRequest ? 'Solo sus amigos pueden verlo. Envíale una solicitud de amistad.' : 'Solo sus amigos pueden verlo.'"
          />
        </div>

        <template v-else>
          <TabNav class="profile__tabs panel" label="Secciones del perfil" :tabs="tabs" :active="tab" :to="tabRoute" />

          <section v-if="tab === 'posts'" class="profile__section" aria-label="Publicaciones">
            <PostComposer v-if="isSelf" />
            <PostList :list="timeline" @retry="feed.loadTimeline(userId)" @more="feed.loadTimeline(userId, { more: true })">
              <template #empty>
                <div class="panel">
                  <StateMessage
                    :icon="UserX"
                    :title="isSelf ? 'Todavía no has publicado nada.' : `${view.profile.firstName} todavía no ha publicado nada.`"
                    :text="isSelf ? 'Cuenta qué estás haciendo: tus amigos lo verán en su inicio.' : ''"
                  />
                </div>
              </template>
            </PostList>
          </section>

          <ProfilePhotos v-else-if="tab === 'photos'" :view="view" />
          <ProfileTaggedPhotos v-else-if="tab === 'tagged'" :view="view" />
          <ProfileAlbums v-else-if="tab === 'albums'" :view="view" />
          <ProfileFriends v-else-if="tab === 'friends'" :view="view" />
          <ProfileInfo v-else :profile="view.profile" :is-self="isSelf" @edit="editing = true" />
        </template>

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

  &__tabs {
    border-radius: 0;
  }

  &__section {
    display: flex;
    flex-direction: column;
    gap: $space-3;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .profile__tabs {
    border-radius: $radius;
  }
}
</style>
