<script setup>
import { onMounted } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import FriendshipButton from '@/components/friends/FriendshipButton.vue'
import { useFriendsStore } from '@/stores/friends'
import { plural } from '@/utils/text'

// STORES
const friends = useFriendsStore()

// LIFECYCLE
onMounted(() => friends.loadSuggestions())
</script>

<template>
  <section v-if="friends.suggestions.items.length" class="panel widget" aria-labelledby="suggestions-title">
    <h2 id="suggestions-title" class="panel-title">Quizá conozcas a</h2>
    <ul class="widget__list" role="list">
      <li v-for="person in friends.suggestions.items" :key="person.id" class="widget__item">
        <UserAvatar :person="person" size="md" />
        <div class="widget__body">
          <PersonLink :person="person" />
          <p class="widget__sub">{{ plural(person.mutualFriends, 'amigo en común', 'amigos en común') }}</p>
          <FriendshipButton class="widget__actions" :person="person" size="sm" />
        </div>
      </li>
    </ul>
  </section>
</template>

<style lang="scss" scoped>
@use '@/styles/partials/widget';
</style>
