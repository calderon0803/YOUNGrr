<script setup>
import { computed, ref, useId } from 'vue'
import { Star, StarHalf } from 'lucide-vue-next'

// Stars from 0.5 to 5 in halves. Read only, or as an input (each star has a
// left half and a right half; arrows change it by half a star).

// PROPS
const props = defineProps({
  modelValue: { type: Number, default: null },
  /** Chosen by the user instead of only shown. */
  editable: { type: Boolean, default: false },
  size: { type: String, default: 'md', validator: (v) => ['sm', 'md', 'lg'].includes(v) },
  label: { type: String, default: 'Valoración' },
})

const emit = defineEmits(['update:modelValue'])

// DATA
const hover = ref(null)
const labelId = useId()

// COMPUTED
const shown = computed(() => hover.value ?? props.modelValue ?? 0)
const stars = computed(() => [1, 2, 3, 4, 5].map((n) => (shown.value >= n ? 'full' : shown.value >= n - 0.5 ? 'half' : 'empty')))
const text = computed(() => (props.modelValue ? `${String(props.modelValue).replace('.', ',')} de 5 estrellas` : 'Sin valorar'))

// METHODS
const pick = (value) => emit('update:modelValue', value)

const onKeydown = (event) => {
  const step = { ArrowRight: 0.5, ArrowUp: 0.5, ArrowLeft: -0.5, ArrowDown: -0.5 }[event.key]
  if (!step) return
  event.preventDefault()
  pick(Math.min(5, Math.max(0.5, (props.modelValue ?? 0) + step)))
}
</script>

<template>
  <span
    v-if="!editable"
    class="stars"
    :class="`stars--${size}`"
    role="img"
    :aria-label="text"
  >
    <span v-for="(state, i) in stars" :key="i" class="stars__star" :class="`stars__star--${state}`">
      <Star aria-hidden="true" />
      <StarHalf v-if="state === 'half'" class="stars__half" aria-hidden="true" />
    </span>
  </span>
  <span
    v-else
    class="stars stars--editable"
    :class="`stars--${size}`"
    role="slider"
    tabindex="0"
    :aria-labelledby="labelId"
    aria-valuemin="0.5"
    aria-valuemax="5"
    :aria-valuenow="modelValue ?? undefined"
    :aria-valuetext="text"
    @keydown="onKeydown"
    @mouseleave="hover = null"
  >
    <span :id="labelId" class="visually-hidden">{{ label }}</span>
    <span v-for="(state, i) in stars" :key="i" class="stars__star" :class="`stars__star--${state}`">
      <Star aria-hidden="true" />
      <StarHalf v-if="state === 'half'" class="stars__half" aria-hidden="true" />
      <button type="button" class="stars__hit stars__hit--left" tabindex="-1" :aria-label="`${i + 0.5} estrellas`" @mouseenter="hover = i + 0.5" @click="pick(i + 0.5)" />
      <button type="button" class="stars__hit stars__hit--right" tabindex="-1" :aria-label="`${i + 1} estrellas`" @mouseenter="hover = i + 1" @click="pick(i + 1)" />
    </span>
  </span>
</template>

<style lang="scss" scoped>
.stars {
  display: inline-flex;
  align-items: center;
  gap: 0.05rem;
  --star-size: 1.1rem;

  &--sm {
    --star-size: 0.85rem;
  }

  &--lg {
    --star-size: 1.75rem;
  }

  &--editable {
    border-radius: $radius-sm;
    cursor: pointer;

    &:focus-visible {
      @include focus-ring;
    }
  }

  &__star {
    position: relative;
    display: inline-flex;
    width: var(--star-size);
    height: var(--star-size);
    color: $color-border-strong;

    svg {
      width: 100%;
      height: 100%;
    }

    &--full {
      color: $color-gold;

      svg {
        fill: currentColor;
      }
    }
  }

  // Half a star: the gold left half over the empty star.
  &__half {
    position: absolute;
    inset: 0;
    color: $color-gold;
    fill: currentColor;
  }

  &__hit {
    @include reset-button;
    position: absolute;
    top: 0;
    bottom: 0;
    width: 50%;

    &--left {
      left: 0;
    }

    &--right {
      right: 0;
    }
  }
}
</style>
