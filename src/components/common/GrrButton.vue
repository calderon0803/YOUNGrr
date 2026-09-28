<script setup>
import { ref, watch } from 'vue'
import { Check } from 'lucide-vue-next'
import GrrIcon from '@/components/common/GrrIcon.vue'

// PROPS
const props = defineProps({
  active: { type: Boolean, default: false },
  count: { type: Number, default: 0 },
  disabled: { type: Boolean, default: false },
  /** What receives the Grr, for the tooltip: "publicación" or "fotografía". */
  target: { type: String, default: 'publicación' },
  onDark: { type: Boolean, default: false },
})

const emit = defineEmits(['toggle'])

// DATA
const swiping = ref(false)

// WATCHERS
// "Swipe" microinteraction only when Grr is made, never when removed.
watch(
  () => props.active,
  (now, before) => {
    if (now && !before) {
      swiping.value = false
      requestAnimationFrame(() => (swiping.value = true))
    }
  },
)
</script>

<template>
  <button
    type="button"
    class="grr"
    :class="{ 'grr--active': active, 'grr--swipe': swiping, 'grr--on-dark': onDark }"
    :aria-pressed="active"
    :disabled="disabled"
    :title="active ? `Quitar tu Grr de esta ${target}` : `Hacer Grr a esta ${target}`"
    @click="emit('toggle')"
    @animationend="swiping = false"
  >
    <GrrIcon class="grr__icon" :active="active" />
    <span class="grr__label">Grr</span>
    <Check v-if="active" class="grr__check" :stroke-width="3" aria-hidden="true" />
    <span v-if="count > 0" class="grr__count">{{ count }}</span>
    <span class="visually-hidden">{{ active ? ', has hecho Grr' : '' }}</span>
  </button>
</template>

<style lang="scss" scoped>
.grr {
  @include reset-button;
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  min-height: 2.25rem;
  padding: 0 $space-3 0 $space-2;
  border: 1px solid transparent;
  border-radius: $radius;
  color: $color-text-muted;
  font-weight: 700;
  font-size: $fs-base;
  transition:
    color $duration-fast,
    background-color $duration-fast,
    border-color $duration-fast,
    transform $duration-fast $ease-out;

  &__label {
    letter-spacing: 0.01em;
  }

  &__check {
    width: 0.8rem;
    height: 0.8rem;
  }

  &__count {
    min-width: 1ch;
    font-variant-numeric: tabular-nums;
    font-weight: 600;
  }

  // Hover
  &:hover:not(:disabled) {
    color: $color-grr;
    background: $color-grr-soft;
  }

  // Pressed
  &:active:not(:disabled) {
    transform: scale(0.94);
  }

  // Active: the user already made Grr
  &--active {
    color: $color-grr-strong;
    background: $color-grr-soft;
    border-color: $color-grr-soft;

    &:hover:not(:disabled) {
      color: $color-grr-strong;
      border-color: $color-grr;
    }
  }

  // Disabled
  &:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  &--on-dark {
    color: $color-viewer-text;

    &:hover:not(:disabled) {
      color: $color-grr-logo;
      background: transparent;
      border-color: $color-grr-logo;
    }

    &.grr--active {
      color: $color-grr-logo;
      background: transparent;
      border-color: $color-grr-logo;
    }
  }

  &--swipe {
    .grr__icon {
      animation: grr-pop 320ms $ease-spring;
    }

    :deep(.grr-icon__claw) {
      stroke-dasharray: 1;
      animation: grr-scratch 260ms $ease-out both;

      &:nth-child(2) {
        animation-delay: 45ms;
      }

      &:nth-child(3) {
        animation-delay: 90ms;
      }
    }
  }
}

@keyframes grr-pop {
  0% {
    transform: scale(1) rotate(0);
  }

  45% {
    transform: scale(1.28) rotate(-10deg);
  }

  100% {
    transform: scale(1) rotate(0);
  }
}

@keyframes grr-scratch {
  from {
    stroke-dashoffset: 1;
  }

  to {
    stroke-dashoffset: 0;
  }
}
</style>
