<script setup>
import { computed, ref } from 'vue'
import { ExternalLink, Music } from 'lucide-vue-next'
import { SPOTIFY } from '@/config/app'
import { spotifyUrl } from '@/utils/spotify'

// A Spotify link in a status: cover, title and what it is, with a link to
// listen to it in Spotify. The data was saved with the status; only the cover
// is loaded from Spotify.

// PROPS
const props = defineProps({
  link: { type: Object, required: true },
  small: { type: Boolean, default: false },
})

// DATA
const coverFailed = ref(false)

// COMPUTED
const kindLabel = computed(() => SPOTIFY.kinds[props.link.kind] ?? 'Spotify')
const showCover = computed(() => props.link.image && !coverFailed.value)
</script>

<template>
  <a
    class="spotify"
    :class="{ 'spotify--small': small }"
    :href="spotifyUrl(link)"
    target="_blank"
    rel="noopener noreferrer"
    :aria-label="`${link.title}, ${kindLabel.toLowerCase()} en Spotify (se abre en otra pestaña)`"
  >
    <img
      v-if="showCover"
      class="spotify__cover"
      :src="link.image"
      alt=""
      width="64"
      height="64"
      loading="lazy"
      referrerpolicy="no-referrer"
      @error="coverFailed = true"
    />
    <span v-else class="spotify__cover spotify__cover--empty" aria-hidden="true"><Music /></span>
    <span class="spotify__info">
      <span class="spotify__title">{{ link.title }}</span>
      <span class="spotify__kind">{{ kindLabel }} · Spotify</span>
      <span class="spotify__open">Escuchar en Spotify <ExternalLink aria-hidden="true" /></span>
    </span>
  </a>
</template>

<style lang="scss" scoped>
.spotify {
  display: flex;
  align-items: center;
  gap: $space-3;
  max-width: 26rem;
  margin-top: $space-2;
  padding: $space-2;
  border: 1px solid $color-border;
  border-left: 3px solid $color-brand;
  border-radius: $radius;
  background: $color-surface-alt;
  color: $color-text;
  text-decoration: none;

  &:hover {
    background: $color-surface-hover;
  }

  &:focus-visible {
    outline: 2px solid $color-focus;
    outline-offset: 2px;
  }

  &__cover {
    flex-shrink: 0;
    width: 4rem;
    height: 4rem;
    border-radius: $radius-sm;
    object-fit: cover;

    &--empty {
      display: grid;
      place-items: center;
      background: $color-brand-tint;
      color: $color-brand;

      svg {
        width: 1.75rem;
        height: 1.75rem;
      }
    }
  }

  &__info {
    display: flex;
    flex-direction: column;
    gap: 0.1rem;
    min-width: 0;
  }

  &__title {
    overflow: hidden;
    font-weight: 700;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__kind {
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__open {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    font-size: $fs-sm;
    color: $color-link;

    svg {
      width: 0.8rem;
      height: 0.8rem;
    }
  }

  &--small {
    gap: $space-2;

    .spotify__cover {
      width: 3rem;
      height: 3rem;
    }
  }
}
</style>
