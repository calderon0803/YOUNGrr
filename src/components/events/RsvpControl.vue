<script setup>
import { ref } from 'vue'
import { useEventsStore } from '@/stores/events'

// PROPS
const props = defineProps({
  event: { type: Object, required: true },
})

// STORES
const events = useEventsStore()

// DATA
const OPTIONS = [
  { value: 'going', label: 'Asistiré' },
  { value: 'maybe', label: 'Quizás' },
  { value: 'declined', label: 'No asistiré' },
]
const saving = ref(false)

// METHODS
const choose = async (status) => {
  if (status === props.event.myStatus || saving.value) return
  saving.value = true
  await events.respond(props.event.id, status)
  saving.value = false
}
</script>

<template>
  <div class="rsvp">
    <p class="rsvp__label" :id="`rsvp-${event.id}`">
      {{ event.myStatus === 'pending' ? 'Te han invitado. ¿Vas a ir?' : 'Tu respuesta' }}
    </p>
    <div class="rsvp__options" role="radiogroup" :aria-labelledby="`rsvp-${event.id}`">
      <button
        v-for="option in OPTIONS"
        :key="option.value"
        type="button"
        role="radio"
        class="rsvp__option"
        :class="[`rsvp__option--${option.value}`, { 'rsvp__option--selected': event.myStatus === option.value }]"
        :aria-checked="event.myStatus === option.value"
        :disabled="saving"
        @click="choose(option.value)"
      >
        {{ option.label }}
      </button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.rsvp {
  &__label {
    margin-bottom: $space-2;
    font-weight: 600;
  }

  &__options {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    overflow: hidden;
    border: 1px solid $color-border-strong;
    border-radius: $radius;
  }

  &__option {
    @include reset-button;
    min-height: 2.5rem;
    padding: 0 $space-2;
    background: $color-surface;
    font-weight: 600;
    font-size: $fs-sm;

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
      &.rsvp__option--going {
        background: $color-success-soft;
        color: $color-success;
      }

      &.rsvp__option--maybe {
        background: $color-brand-tint;
        color: $color-brand-strong;
      }

      &.rsvp__option--declined {
        background: $color-surface-hover;
        color: $color-text;
      }
    }
  }
}
</style>
