<script setup>
import { MapPin } from 'lucide-vue-next'
import { NEARBY_RADII_KM } from '@/config/app'

// PROPS
defineProps({
  modelValue: { type: Number, required: true },
  city: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
})

const emit = defineEmits(['update:modelValue'])
</script>

<template>
  <div class="radius">
    <p id="radius-label" class="radius__label">
      <MapPin aria-hidden="true" />
      <span>Gente a menos de</span>
    </p>
    <div class="radius__options" role="radiogroup" aria-labelledby="radius-label">
      <button
        v-for="km in NEARBY_RADII_KM"
        :key="km"
        type="button"
        role="radio"
        class="radius__option"
        :class="{ 'radius__option--selected': km === modelValue }"
        :aria-checked="km === modelValue"
        :disabled="disabled"
        @click="emit('update:modelValue', km)"
      >
        {{ km }} km
      </button>
    </div>
    <p v-if="city" class="radius__city">de {{ city }}</p>
  </div>
</template>

<style lang="scss" scoped>
.radius {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: $space-2;
  padding: $space-3 $space-4;

  &__label,
  &__city {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    font-size: $fs-sm;
    color: $color-text-muted;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }

  &__city {
    font-weight: 600;
    color: $color-text;
  }

  &__options {
    display: inline-flex;
    overflow: hidden;
    border: 1px solid $color-border-strong;
    border-radius: $radius;
  }

  &__option {
    @include reset-button;
    min-height: 2rem;
    padding: 0 $space-3;
    background: $color-surface;
    font-size: $fs-sm;
    font-weight: 600;

    & + & {
      border-left: 1px solid $color-border-strong;
    }

    &:hover:not(:disabled) {
      background: $color-surface-hover;
    }

    &:disabled {
      cursor: wait;
    }

    &--selected {
      background: $color-brand;
      color: $color-on-brand;

      &:hover:not(:disabled) {
        background: $color-header-hover;
      }
    }
  }
}
</style>
