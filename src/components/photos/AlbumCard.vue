<script setup>
import { computed } from 'vue'
import { Images } from 'lucide-vue-next'
import { fullDate } from '@/utils/time'
import { plural } from '@/utils/text'

// PROPS
const props = defineProps({
  album: { type: Object, required: true },
  showOwner: { type: Boolean, default: false },
})

// COMPUTED
const title = computed(() => (props.album.kind === 'wall' ? 'Fotos del muro' : props.album.title))
</script>

<template>
  <li class="album">
    <RouterLink class="album__link" :to="{ name: 'album', params: { id: album.id } }">
      <span class="album__cover">
        <img v-if="album.coverUrl" :src="album.coverUrl" alt="" loading="lazy" decoding="async" />
        <Images v-else class="album__placeholder" aria-hidden="true" />
      </span>
      <span class="album__title">{{ title }}</span>
      <span class="album__meta">
        {{ plural(album.photoCount, 'foto', 'fotos') }}
        <template v-if="showOwner"> · {{ album.owner.firstName }}</template>
        <template v-else> · {{ fullDate(album.updatedAt) }}</template>
      </span>
    </RouterLink>
  </li>
</template>

<style lang="scss" scoped>
.album {
  min-width: 0;

  &__link {
    display: flex;
    flex-direction: column;
    gap: 0.1rem;
    color: $color-text;

    &:hover {
      text-decoration: none;

      .album__title {
        text-decoration: underline;
      }

      .album__cover {
        transform: rotate(-1deg);
      }
    }
  }

  // The stacked-prints look: a cover with a second print peeking behind.
  &__cover {
    position: relative;
    display: grid;
    place-items: center;
    aspect-ratio: 4 / 3;
    margin-bottom: $space-2;
    background: $color-skeleton;
    border: 3px solid $color-surface;
    border-radius: $radius-sm;
    box-shadow:
      0 1px 2px $color-shadow,
      4px 4px 0 -1px $color-surface,
      4px 4px 0 0 $color-border-strong;
    transition: transform $duration $ease-out;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__placeholder {
    width: 2rem;
    height: 2rem;
    color: $color-text-soft;
  }

  &__title {
    @include truncate;
    font-weight: 700;
  }

  &__meta {
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
