<script setup>
// PROPS
defineProps({
  variant: { type: String, default: 'list', validator: (v) => ['list', 'post', 'grid', 'block'].includes(v) },
  count: { type: Number, default: 3 },
})
</script>

<template>
  <div class="skeleton" :class="`skeleton--${variant}`">
    <span class="visually-hidden">Cargando…</span>
    <template v-if="variant === 'grid'">
      <div v-for="n in count" :key="n" class="skeleton__tile" />
    </template>
    <template v-else-if="variant === 'block'">
      <div class="skeleton__block" />
    </template>
    <template v-else>
      <div v-for="n in count" :key="n" class="skeleton__row" :class="{ 'skeleton__row--post': variant === 'post' }">
        <div class="skeleton__avatar" />
        <div class="skeleton__lines">
          <div class="skeleton__line skeleton__line--short" />
          <div class="skeleton__line" />
          <div v-if="variant === 'post'" class="skeleton__media" />
        </div>
      </div>
    </template>
  </div>
</template>

<style lang="scss" scoped>
@mixin shimmer {
  background: $color-skeleton;
  border-radius: $radius-sm;
  animation: skeleton-pulse 1.4s ease-in-out infinite;
}

.skeleton {
  &--grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 2px;
  }

  &__tile {
    @include shimmer;
    aspect-ratio: 1;
    border-radius: 0;
  }

  &__block {
    @include shimmer;
    height: 12rem;
  }

  &__row {
    display: flex;
    gap: $space-3;
    padding: $space-4;

    & + & {
      border-top: 1px solid $color-border;
    }

    &--post {
      @include panel;
      margin-bottom: $space-3;

      & + & {
        border-top: 1px solid $color-border;
      }
    }
  }

  &__avatar {
    @include shimmer;
    flex-shrink: 0;
    width: 2.5rem;
    height: 2.5rem;
  }

  &__lines {
    display: flex;
    flex: 1;
    flex-direction: column;
    gap: $space-2;
  }

  &__line {
    @include shimmer;
    height: 0.75rem;

    &--short {
      width: 40%;
    }
  }

  &__media {
    @include shimmer;
    height: 10rem;
    margin-top: $space-2;
  }
}

@keyframes skeleton-pulse {
  50% {
    opacity: 0.55;
  }
}
</style>
