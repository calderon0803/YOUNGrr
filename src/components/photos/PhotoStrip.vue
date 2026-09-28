<script setup>
// A row of small photo thumbnails, like Tuenti's news items. The last cell can
// link to the rest ("+3").

// PROPS
defineProps({
  /** [{ id, url }] */
  photos: { type: Array, required: true },
  label: { type: String, required: true },
  /** Photos not shown; with `moreTo`, a "+N" cell links to them. */
  moreCount: { type: Number, default: 0 },
  moreTo: { type: [Object, String], default: null },
})

const emit = defineEmits(['open'])
</script>

<template>
  <ul class="strip" :aria-label="label">
    <li v-for="p in photos" :key="p.id">
      <button type="button" class="strip__thumb" aria-label="Abrir fotografía" @click="emit('open', p.id)">
        <img v-if="p.url" :src="p.url" alt="" loading="lazy" decoding="async" />
      </button>
    </li>
    <li v-if="moreCount > 0 && moreTo">
      <RouterLink class="strip__more" :to="moreTo">+{{ moreCount }}</RouterLink>
    </li>
  </ul>
</template>

<style lang="scss" scoped>
.strip {
  display: flex;
  flex-wrap: wrap;
  gap: $space-1;
  margin: $space-2 0 0;
  padding: 0;
  list-style: none;

  // Reset first so the shared box below wins.
  &__thumb {
    @include reset-button;
    cursor: zoom-in;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__thumb,
  &__more {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 4.5rem;
    height: 4.5rem;
    padding: 2px;
    background: $color-surface;
    border: 1px solid $color-border-strong;
    border-radius: $radius-sm;

    &:hover {
      border-color: $color-brand;
      text-decoration: none;
    }
  }

  &__more {
    font-weight: 700;
    color: $color-link;
    background: $color-surface-alt;
  }
}
</style>
