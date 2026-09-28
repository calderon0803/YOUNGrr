<script setup>
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'

// PROPS
defineProps({
  comment: { type: Object, required: true },
  canDelete: { type: Boolean, default: false },
  onDark: { type: Boolean, default: false },
})

const emit = defineEmits(['delete'])
</script>

<template>
  <li class="comment" :class="{ 'comment--on-dark': onDark }">
    <UserAvatar :person="comment.author" size="sm" />
    <div class="comment__body">
      <p class="comment__text">
        <PersonLink class="comment__author" :person="comment.author" />
        <span class="user-text">{{ comment.text }}</span>
      </p>
      <p class="comment__meta">
        <RelativeTime :value="comment.createdAt" />
        <template v-if="canDelete">
          <span aria-hidden="true">·</span>
          <button type="button" class="comment__delete" @click="emit('delete', comment.id)">Eliminar</button>
        </template>
      </p>
    </div>
  </li>
</template>

<style lang="scss" scoped>
.comment {
  display: flex;
  gap: $space-2;
  padding: $space-2 0;

  &__body {
    min-width: 0;
  }

  &__text {
    line-height: 1.4;
  }

  &__author {
    margin-right: $space-1;
  }

  &__meta {
    display: flex;
    gap: $space-1;
    margin-top: 0.1rem;
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__delete {
    @include reset-button;
    color: $color-text-muted;

    &:hover {
      color: $color-danger;
      text-decoration: underline;
    }
  }

  &--on-dark {
    .comment__meta,
    .comment__delete {
      color: $color-text-soft;
    }

    :deep(.person-link) {
      color: $color-link;
    }
  }
}
</style>
