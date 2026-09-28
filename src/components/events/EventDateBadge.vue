<script setup>
import { computed } from 'vue'
import { eventDayParts } from '@/utils/time'

// PROPS
const props = defineProps({
  date: { type: String, required: true },
  large: { type: Boolean, default: false },
})

// COMPUTED
const parts = computed(() => eventDayParts(props.date))
</script>

<template>
  <span class="date-badge" :class="{ 'date-badge--large': large }" aria-hidden="true">
    <span class="date-badge__month">{{ parts.month }}</span>
    <span class="date-badge__day">{{ parts.day }}</span>
  </span>
</template>

<style lang="scss" scoped>
.date-badge {
  display: inline-flex;
  flex-shrink: 0;
  flex-direction: column;
  align-items: center;
  width: 2.75rem;
  overflow: hidden;
  border: 1px solid $color-border-strong;
  border-radius: $radius;
  background: $color-surface;
  line-height: 1;

  &__month {
    width: 100%;
    padding: 0.2rem 0;
    background: $color-grr;
    color: $color-on-brand;
    font-size: 0.625rem;
    font-weight: 700;
    text-align: center;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  &__day {
    padding: 0.3rem 0 0.35rem;
    font-family: $font-display;
    font-size: $fs-lg;
    font-weight: 800;
  }

  &--large {
    width: 3.75rem;

    .date-badge__month {
      font-size: $fs-xs;
    }

    .date-badge__day {
      font-size: $fs-xl;
    }
  }
}
</style>
