<script setup>
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import FriendshipButton from '@/components/friends/FriendshipButton.vue'
import { plural } from '@/utils/text'

// PROPS
defineProps({
  /** PersonView */
  person: { type: Object, required: true },
  showAction: { type: Boolean, default: true },
})
</script>

<template>
  <li class="person">
    <RouterLink :to="{ name: 'profile', params: { id: person.id } }" tabindex="-1" aria-hidden="true">
      <UserAvatar :person="person" size="lg" />
    </RouterLink>
    <div class="person__body">
      <PersonLink :person="person" />
      <p class="person__sub">
        <span v-if="person.city">{{ person.city }}</span>
        <span v-if="person.mutualFriends && person.friendship !== 'self'">{{ plural(person.mutualFriends, 'amigo en común', 'amigos en común') }}</span>
      </p>
      <FriendshipButton v-if="showAction && person.friendship !== 'self'" class="person__action" :person="person" size="sm" />
    </div>
  </li>
</template>

<style lang="scss" scoped>
.person {
  display: flex;
  gap: $space-3;
  padding: $space-3;
  min-width: 0;

  &__body {
    display: flex;
    flex: 1;
    flex-direction: column;
    align-items: flex-start;
    min-width: 0;
  }

  &__sub {
    display: flex;
    flex-wrap: wrap;
    gap: 0 $space-2;
    font-size: $fs-sm;
    color: $color-text-muted;

    span + span::before {
      content: '·';
      margin-right: $space-2;
    }
  }

  &__action {
    margin-top: $space-2;
  }
}
</style>
