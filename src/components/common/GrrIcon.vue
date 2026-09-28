<script setup>
// The Grr mark: three claw scratches. Same 24px grid and stroke family as Lucide.

// PROPS
defineProps({
  active: { type: Boolean, default: false },
})
</script>

<template>
  <svg
    class="grr-icon"
    :class="{ 'grr-icon--active': active }"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
    focusable="false"
  >
    <path class="grr-icon__claw" d="M7.5 3.5c1.6 4.6 1 9.8-3 15.5" pathLength="1" />
    <path class="grr-icon__claw" d="M13 3c1.7 5 1.1 10.6-3.1 17.5" pathLength="1" />
    <path class="grr-icon__claw" d="M18.5 4.5c1.5 4.4.9 9.2-3 14.5" pathLength="1" />
  </svg>
</template>

<style lang="scss" scoped>
.grr-icon {
  width: 1.25rem;
  height: 1.25rem;
  stroke-width: 2;
  transition: stroke-width $duration-fast;

  &--active {
    stroke-width: 2.75;
  }
}
</style>
