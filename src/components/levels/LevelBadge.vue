<script setup>
import { computed } from 'vue'
import { levelTone } from '@/config/levels'

// "Nivel 12": its look changes every few levels (bronze from 10, silver from
// 20, gold from 30, platinum from 50). Only recognition.

// PROPS
const props = defineProps({
  level: { type: Number, required: true },
})

// COMPUTED
const tone = computed(() => levelTone(props.level))
</script>

<template>
  <span class="level-badge" :class="`level-badge--${tone}`">Nivel {{ level }}</span>
</template>

<style lang="scss" scoped>
.level-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.1rem $space-2;
  border: 1px solid $color-border;
  border-radius: $radius-pill;
  background: $color-brand-tint;
  color: $color-brand-strong;
  font-size: $fs-xs;
  font-weight: 700;
  white-space: nowrap;

  &--bronze {
    background: $color-bronze-soft;
    border-color: $color-bronze-border;
    color: $color-bronze;
  }

  &--silver {
    background: $color-silver-soft;
    border-color: $color-silver-border;
    color: $color-silver;
  }

  &--gold {
    background: $color-gold-soft;
    border-color: $color-gold-border;
    color: $color-gold;
  }

  &--platinum {
    background: $color-platinum-soft;
    border-color: $color-platinum-border;
    color: $color-platinum;
  }
}
</style>
