<script setup>
// PROPS
defineProps({
  /** "Yrr" mark for tight spaces. */
  compact: { type: Boolean, default: false },
  onDark: { type: Boolean, default: false },
  size: { type: String, default: 'md', validator: (v) => ['sm', 'md', 'lg', 'xl'].includes(v) },
})
</script>

<template>
  <span
    class="logo"
    :class="[`logo--${size}`, { 'logo--on-dark': onDark }]"
    :role="compact ? 'img' : undefined"
    :aria-label="compact ? 'YOUNGrr' : undefined"
  >
    <span class="logo__young" :aria-hidden="compact || undefined">{{ compact ? 'Y' : 'YOUNG' }}</span><span
      class="logo__rr"
      :aria-hidden="compact || undefined"
      >rr</span
    >
  </span>
</template>

<style lang="scss" scoped>
.logo {
  display: inline-flex;
  align-items: baseline;
  font-family: $font-display;
  font-weight: 800;
  line-height: 1;
  letter-spacing: -0.035em;
  color: $color-link;
  user-select: none;

  &__rr {
    margin-left: 0.04em;
    font-weight: 700;
    letter-spacing: -0.02em;
    color: $color-grr;
  }

  &--on-dark {
    color: $color-on-brand;

    .logo__rr {
      color: $color-grr-logo;
    }
  }

  &--sm {
    font-size: 1.125rem;
  }

  &--md {
    font-size: 1.5rem;
  }

  &--lg {
    font-size: 2.25rem;
  }

  &--xl {
    font-size: 3.5rem;
  }
}
</style>
