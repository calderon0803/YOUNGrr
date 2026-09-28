<script setup>
import { computed, ref, watch } from 'vue'
import { fullName, initials } from '@/utils/text'

// PROPS
const props = defineProps({
  person: { type: Object, default: null },
  size: { type: String, default: 'md', validator: (v) => ['xs', 'sm', 'md', 'lg', 'xl'].includes(v) },
  /** Avatars next to the name are decorative; standalone ones need alt text. */
  decorative: { type: Boolean, default: true },
})

// DATA
const failed = ref(false)

// COMPUTED
const showImage = computed(() => !!props.person?.avatarUrl && !failed.value)
// Stable tint per person for the initials fallback.
const tint = computed(() => ((props.person?.id ?? '').split('').reduce((sum, c) => sum + c.charCodeAt(0), 0) % 3) + 1)

// WATCHERS
watch(
  () => props.person?.avatarUrl,
  () => (failed.value = false),
)
</script>

<template>
  <span class="avatar" :class="[`avatar--${size}`, `avatar--tint-${tint}`]">
    <img
      v-if="showImage"
      :src="person.avatarUrl"
      :alt="decorative ? '' : fullName(person)"
      loading="lazy"
      decoding="async"
      @error="failed = true"
    />
    <span v-else class="avatar__initials" :aria-hidden="decorative || undefined" :aria-label="decorative ? undefined : fullName(person)">
      {{ initials(person) }}
    </span>
  </span>
</template>

<style lang="scss" scoped>
.avatar {
  --size: 2.5rem;

  position: relative;
  display: inline-flex;
  flex-shrink: 0;
  width: var(--size);
  height: var(--size);
  overflow: hidden;
  border-radius: $radius;
  background: $color-brand-soft;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  &__initials {
    display: grid;
    place-items: center;
    width: 100%;
    height: 100%;
    font-family: $font-display;
    font-weight: 700;
    font-size: calc(var(--size) * 0.38);
    color: $color-brand-strong;
  }

  &--tint-2 {
    background: $color-grr-soft;

    .avatar__initials {
      color: $color-grr-strong;
    }
  }

  &--tint-3 {
    background: $color-surface-hover;

    .avatar__initials {
      color: $color-text-muted;
    }
  }

  &--xs {
    --size: 1.5rem;
    border-radius: $radius-sm;
  }

  &--sm {
    --size: 2rem;
    border-radius: $radius-sm;
  }

  &--md {
    --size: 2.5rem;
  }

  &--lg {
    --size: 3.5rem;
  }

  &--xl {
    --size: 7rem;
    border-radius: $radius-lg;
  }
}
</style>
