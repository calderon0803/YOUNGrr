<script setup>
import { computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { Users } from 'lucide-vue-next'
import TabNav from '@/components/common/TabNav.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PersonGrid from '@/components/friends/PersonGrid.vue'
import FriendRequests from '@/components/friends/FriendRequests.vue'
import PeopleSearch from '@/components/friends/PeopleSearch.vue'
import { useFriendsStore } from '@/stores/friends'
import { useAuthStore } from '@/stores/auth'
import { useNotificationsStore } from '@/stores/notifications'

// STORES
const route = useRoute()
const friends = useFriendsStore()
const auth = useAuthStore()
const notifications = useNotificationsStore()

// DATA
const TAB_KEYS = ['friends', 'requests', 'search']

// COMPUTED
const tab = computed(() => (TAB_KEYS.includes(route.query.tab) ? route.query.tab : 'friends'))
const mine = computed(() => friends.lists[auth.meId] ?? { status: 'loading', items: [], error: null })
const tabs = computed(() => [
  { key: 'friends', label: 'Mis amigos' },
  { key: 'requests', label: 'Solicitudes', count: friends.incomingCount },
  { key: 'search', label: 'Buscar personas' },
])

// METHODS
const tabRoute = (key) => ({ query: key === 'friends' ? {} : { tab: key } })

const load = () => {
  if (tab.value === 'friends') friends.loadFriends(auth.meId)
  if (tab.value === 'requests') friends.loadRequests()
}

// LIFECYCLE
onMounted(() => {
  load()
  notifications.markSeen({ list: 'friends' })
})

// WATCHERS
watch(tab, load)
</script>

<template>
  <div class="friends-page">
    <h1 class="page-title friends-page__title">Amigos</h1>
    <div class="panel friends-page__panel">
      <TabNav label="Secciones de amigos" :tabs="tabs" :active="tab" :to="tabRoute" />

      <AsyncState v-if="tab === 'friends'" :status="mine.status" :error="mine.error" :empty="!mine.items.length" @retry="load">
        <template #empty>
          <StateMessage :icon="Users" title="Todavía no tienes amigos." text="Busca personas para empezar.">
            <RouterLink class="btn btn--primary" :to="tabRoute('search')">Buscar personas</RouterLink>
          </StateMessage>
        </template>
        <PersonGrid :people="mine.items" label="Mis amigos" />
      </AsyncState>

      <FriendRequests v-else-if="tab === 'requests'" />
      <PeopleSearch v-else />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.friends-page {
  &__title {
    padding: 0 $space-4;
  }

  &__panel {
    border-radius: 0;
    border-right: 0;
    border-left: 0;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .friends-page {
    &__title {
      padding: 0;
    }

    &__panel {
      border-right: 1px solid $color-border;
      border-left: 1px solid $color-border;
      border-radius: $radius;
    }
  }
}
</style>
