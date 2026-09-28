<script setup>
import { computed } from 'vue'
import { MessageSquare } from 'lucide-vue-next'
import GrrIcon from '@/components/common/GrrIcon.vue'
import { usePhotosStore } from '@/stores/photos'

// PROPS
const props = defineProps({
  ids: { type: Array, required: true },
  label: { type: String, required: true },
})

// STORES
const photos = usePhotosStore()

// COMPUTED
const items = computed(() => props.ids.map((id) => photos.photos[id]).filter(Boolean))

// METHODS
const open = (index) => photos.openViewer(items.value.map((p) => p.id), index)
</script>

<template>
  <ul class="photo-grid" role="list" :aria-label="label">
    <li v-for="(photo, index) in items" :key="photo.id" class="photo-grid__item">
      <button type="button" class="photo-grid__button" :aria-label="`Abrir fotografía ${index + 1} de ${items.length}${photo.caption ? `: ${photo.caption}` : ''}`" @click="open(index)">
        <img :src="photo.url" alt="" loading="lazy" decoding="async" />
        <span v-if="photo.grrCount || photo.commentCount" class="photo-grid__stats" aria-hidden="true">
          <span v-if="photo.grrCount"><GrrIcon :active="photo.hasGrr" /> {{ photo.grrCount }}</span>
          <span v-if="photo.commentCount"><MessageSquare /> {{ photo.commentCount }}</span>
        </span>
      </button>
    </li>
  </ul>
</template>

<style lang="scss" scoped>
.photo-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 2px;
  margin: 0;

  &__item {
    aspect-ratio: 1;
    min-width: 0;
    background: $color-skeleton;
  }

  &__button {
    @include reset-button;
    position: relative;
    display: block;
    width: 100%;
    height: 100%;
    overflow: hidden;
    cursor: zoom-in;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      transition: transform 400ms $ease-out;
    }

    &:hover img {
      transform: scale(1.04);
    }

    &:focus-visible {
      outline-offset: -3px;
    }
  }

  &__stats {
    position: absolute;
    right: 0;
    bottom: 0;
    left: 0;
    display: flex;
    gap: $space-3;
    padding: $space-4 $space-2 $space-1;
    background: linear-gradient(transparent, $color-overlay);
    color: $color-on-brand;
    font-size: $fs-xs;
    font-weight: 700;

    span {
      display: inline-flex;
      align-items: center;
      gap: 0.2rem;
    }

    svg {
      width: 0.9rem;
      height: 0.9rem;
    }
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .photo-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: $space-1;
  }
}

@media (min-width: $bp-desktop) {
  .photo-grid {
    grid-template-columns: repeat(5, minmax(0, 1fr));
  }
}
</style>
