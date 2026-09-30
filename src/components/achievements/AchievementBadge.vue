<script setup>
import { computed } from 'vue'
import { ACHIEVEMENTS, achievementLabel } from '@/config/achievements'

// One achievement: its icon in a round badge whose look says the level
// (bronce, plata, oro, platino; single-level ones have their own look).
// Not earned yet: a muted outline.

// PROPS
const props = defineProps({
  code: { type: String, required: true },
  /** 0 when not earned yet. */
  level: { type: Number, default: 1 },
  size: { type: String, default: 'md' },
})

// COMPUTED
const def = computed(() => ACHIEVEMENTS[props.code])
const tiered = computed(() => (def.value?.thresholds.length ?? 1) > 1)
const tone = computed(() => {
  if (!props.level) return 'none'
  return tiered.value ? `tier-${props.level}` : 'single'
})
const label = computed(() => (props.level ? achievementLabel(props.code, props.level) : `${def.value?.name ?? props.code} (sin conseguir)`))
</script>

<template>
  <span v-if="def" class="badge" :class="[`badge--${size}`, `badge--${tone}`]" role="img" :aria-label="label" :title="label">
    <component :is="def.icon" class="badge__icon" aria-hidden="true" />
  </span>
</template>

<style lang="scss" scoped>
.badge {
  display: inline-grid;
  flex-shrink: 0;
  place-items: center;
  width: 2.75rem;
  height: 2.75rem;
  border: 2px solid transparent;
  border-radius: 50%;

  &__icon {
    width: 55%;
    height: 55%;
  }

  &--sm {
    width: 2rem;
    height: 2rem;
  }

  &--none {
    border-color: $color-border;
    border-style: dashed;
    color: $color-text-soft;
  }

  &--single {
    background: $color-brand-tint;
    border-color: $color-brand-soft;
    color: $color-brand-strong;
  }

  &--tier-1 {
    background: $color-bronze-soft;
    border-color: $color-bronze-border;
    color: $color-bronze;
  }

  &--tier-2 {
    background: $color-silver-soft;
    border-color: $color-silver-border;
    color: $color-silver;
  }

  &--tier-3 {
    background: $color-gold-soft;
    border-color: $color-gold-border;
    color: $color-gold;
  }

  &--tier-4 {
    background: $color-platinum-soft;
    border-color: $color-platinum-border;
    color: $color-platinum;
  }
}
</style>
