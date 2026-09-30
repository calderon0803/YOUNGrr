<script setup>
import { Lock } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { groupAvatar, groupKindLabel } from '@/utils/groups'
import { plural } from '@/utils/text'

// One group in a list: its initials, name, privacy and people, with room for
// actions (accept an invitation, ask to join...).

// PROPS
defineProps({
  group: { type: Object, required: true },
  /** Shows the count of new posts in its Gallinero. */
  showNew: { type: Boolean, default: false },
})
</script>

<template>
  <li class="group-item">
    <UserAvatar :person="groupAvatar(group)" size="md" />
    <span class="group-item__body">
      <RouterLink class="group-item__name" :to="{ name: 'group', params: { id: group.id } }">{{ group.name }}</RouterLink>
      <span class="group-item__meta">
        <Lock v-if="group.privacy === 'secret'" aria-hidden="true" />
        {{ groupKindLabel(group) }} · {{ plural(group.memberCount, 'persona', 'personas') }}
      </span>
      <span v-if="group.invitedBy" class="group-item__meta">Te invita {{ group.invitedBy.firstName }}</span>
      <span v-if="$slots.default" class="group-item__actions"><slot /></span>
    </span>
    <span v-if="showNew && group.newPosts" class="group-item__new">
      {{ group.newPosts }} <span class="visually-hidden">{{ group.newPosts === 1 ? 'publicación nueva' : 'publicaciones nuevas' }}</span>
    </span>
  </li>
</template>

<style lang="scss" scoped>
.group-item {
  display: flex;
  align-items: flex-start;
  gap: $space-3;
  padding: $space-3;

  & + & {
    border-top: 1px solid $color-border;
  }

  &__body {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
  }

  &__name {
    @include truncate;
    font-weight: 700;
  }

  &__meta {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    font-size: $fs-sm;
    color: $color-text-muted;

    svg {
      width: 0.85rem;
      height: 0.85rem;
    }
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: $space-2;
    margin-top: $space-2;
  }

  &__new {
    flex-shrink: 0;
    align-self: center;
    min-width: 1.5rem;
    padding: 0.1rem $space-2;
    border-radius: $radius-pill;
    background: $color-success;
    color: $color-on-brand;
    font-size: $fs-xs;
    font-weight: 700;
    text-align: center;
  }
}
</style>
