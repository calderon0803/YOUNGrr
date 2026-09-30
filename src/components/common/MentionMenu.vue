<script setup>
import UserAvatar from '@/components/common/UserAvatar.vue'
import { fullName } from '@/utils/text'

// The people suggested after typing "@" (see useMentions).

// PROPS
defineProps({
  suggestions: { type: Array, required: true },
  active: { type: Number, required: true },
  /** Where it opens: below the field or above it (chat). */
  placement: { type: String, default: 'bottom' },
})

const emit = defineEmits(['pick'])
</script>

<template>
  <ul v-if="suggestions.length" class="mentions" :class="`mentions--${placement}`" role="listbox" aria-label="Mencionar a">
    <li
      v-for="(person, i) in suggestions"
      :key="person.id"
      class="mentions__item"
      :class="{ 'mentions__item--active': i === active }"
      role="option"
      :aria-selected="i === active"
      @mousedown.prevent="emit('pick', person)"
    >
      <UserAvatar :person="person" size="xs" />
      <span>{{ fullName(person) }}</span>
    </li>
  </ul>
</template>

<style lang="scss" scoped>
.mentions {
  position: absolute;
  left: 0;
  z-index: $z-dropdown;
  min-width: 14rem;
  max-width: 100%;
  margin: 0;
  padding: $space-1;
  border: 1px solid $color-border;
  border-radius: $radius;
  background: $color-surface;
  box-shadow: 0 4px 12px $color-shadow;

  &--bottom {
    top: 100%;
    margin-top: $space-1;
  }

  &--top {
    bottom: 100%;
    margin-bottom: $space-1;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: $space-2;
    padding: $space-1 $space-2;
    border-radius: $radius-sm;
    font-size: $fs-sm;
    cursor: pointer;

    &--active,
    &:hover {
      background: $color-surface-hover;
    }
  }
}
</style>
