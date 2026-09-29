<script setup>
import { computed, onMounted } from 'vue'
import { Users } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PersonGrid from '@/components/friends/PersonGrid.vue'
import { useFriendsStore } from '@/stores/friends'
import { plural } from '@/utils/text'

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

// STORES
const friends = useFriendsStore()

// COMPUTED
const userId = computed(() => props.view.profile.id)
const state = computed(() => friends.lists[userId.value] ?? { status: 'loading', items: [], error: null })
const isSelf = computed(() => props.view.friendship === 'self')

// METHODS
const load = () => friends.loadFriends(userId.value)

// LIFECYCLE
onMounted(load)
</script>

<template>
  <section class="panel" aria-labelledby="profile-friends-title">
    <h2 id="profile-friends-title" class="visually-hidden">{{ plural(view.friendsCount, 'amigo', 'amigos') }}</h2>
    <AsyncState :status="state.status" :error="state.error" :empty="!state.items.length" @retry="load">
      <template #empty>
        <StateMessage :icon="Users" :title="isSelf ? 'Todavía no tienes amigos.' : 'Todavía no tiene amigos en YOUNGrr.'" :text="isSelf ? 'Busca personas para empezar.' : ''">
          <RouterLink v-if="isSelf" class="btn btn--primary" :to="{ name: 'friends', query: { tab: 'search' } }">Buscar personas</RouterLink>
        </StateMessage>
      </template>
      <PersonGrid :people="state.items" label="Amigos" />
    </AsyncState>
  </section>
</template>
