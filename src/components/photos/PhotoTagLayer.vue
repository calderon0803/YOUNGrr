<script setup>
import { fullName } from '@/utils/text'

// Tag boxes drawn over the photo. Visible on hover (desktop), when `visible`
// is on (touch), or for the tag highlighted from the side panel.

// PROPS
defineProps({
  tags: { type: Array, required: true },
  visible: { type: Boolean, default: false },
  highlightId: { type: String, default: null },
  /** Pending tag position while choosing a friend. */
  draft: { type: Object, default: null },
})
</script>

<template>
  <div class="tag-layer" :class="{ 'tag-layer--visible': visible }" aria-hidden="true">
    <span
      v-for="tag in tags"
      :key="tag.id"
      class="tag-layer__tag"
      :class="{ 'tag-layer__tag--highlight': tag.id === highlightId }"
      :style="{ left: `${tag.x * 100}%`, top: `${tag.y * 100}%` }"
    >
      <span class="tag-layer__box" />
      <span class="tag-layer__name">{{ fullName(tag.person) }}</span>
    </span>
    <span v-if="draft" class="tag-layer__tag tag-layer__tag--draft" :style="{ left: `${draft.x * 100}%`, top: `${draft.y * 100}%` }">
      <span class="tag-layer__box" />
    </span>
  </div>
</template>

<style lang="scss" scoped>
.tag-layer {
  position: absolute;
  inset: 0;
  pointer-events: none;

  &__tag {
    position: absolute;
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 16%;
    opacity: 0;
    transform: translate(-50%, -50%);
    transition: opacity $duration-fast;

    &--highlight,
    &--draft {
      opacity: 1;
    }
  }

  &__box {
    width: 100%;
    aspect-ratio: 1;
    border: 2px solid $color-on-brand;
    border-radius: $radius-sm;
    box-shadow:
      0 0 0 1px $color-overlay,
      inset 0 0 0 1px $color-overlay;
  }

  &__tag--draft &__box {
    border-style: dashed;
    border-color: $color-grr-logo;
  }

  &__name {
    margin-top: $space-1;
    padding: 0.1rem $space-2;
    border-radius: $radius-sm;
    background: $color-toast-bg;
    color: $color-toast-text;
    font-size: $fs-xs;
    font-weight: 700;
    white-space: nowrap;
  }

  &--visible &__tag {
    opacity: 1;
  }
}
</style>
