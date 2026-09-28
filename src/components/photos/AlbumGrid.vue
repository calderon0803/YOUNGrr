<script setup>
import AlbumCard from '@/components/photos/AlbumCard.vue'

// PROPS
defineProps({
  albums: { type: Array, required: true },
  label: { type: String, required: true },
  showOwner: { type: Boolean, default: false },
})
</script>

<template>
  <ul class="album-grid" role="list" :aria-label="label">
    <AlbumCard v-for="album in albums" :key="album.id" :album="album" :show-owner="showOwner" />
  </ul>
</template>

<style lang="scss" scoped>
.album-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: $space-5 $space-4;
  margin: 0;
  padding: $space-4;
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .album-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (min-width: $bp-desktop) {
  .album-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}
</style>
