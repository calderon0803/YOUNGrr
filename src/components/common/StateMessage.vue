<script setup>
// Empty and error states: always explain what happened and what to do next.

// PROPS
defineProps({
  title: { type: String, required: true },
  text: { type: String, default: '' },
  /** A Lucide icon component, optional. */
  icon: { type: [Object, Function], default: null },
  tone: { type: String, default: 'neutral', validator: (v) => ['neutral', 'error'].includes(v) },
  compact: { type: Boolean, default: false },
})
</script>

<template>
  <div class="state" :class="[`state--${tone}`, { 'state--compact': compact }]" :role="tone === 'error' ? 'alert' : undefined">
    <component :is="icon" v-if="icon" class="state__icon" aria-hidden="true" />
    <p class="state__title">{{ title }}</p>
    <p v-if="text" class="state__text">{{ text }}</p>
    <div v-if="$slots.default" class="state__actions">
      <slot />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: $space-1;
  padding: $space-8 $space-4;
  text-align: center;

  &__icon {
    width: 1.75rem;
    height: 1.75rem;
    margin-bottom: $space-2;
    color: $color-text-soft;
  }

  &__title {
    font-weight: 700;
    font-size: $fs-md;
  }

  &__text {
    max-width: 28rem;
    color: $color-text-muted;
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: $space-2;
    margin-top: $space-3;
  }

  &--error {
    .state__icon {
      color: $color-danger;
    }
  }

  &--compact {
    padding: $space-5 $space-4;

    .state__title {
      font-size: $fs-base;
    }
  }
}
</style>
