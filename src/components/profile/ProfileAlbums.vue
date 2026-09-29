<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Images, Plus } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import AlbumGrid from '@/components/photos/AlbumGrid.vue'
import AlbumFormDialog from '@/components/photos/AlbumFormDialog.vue'
import { usePhotosStore } from '@/stores/photos'

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

// STORES
const photos = usePhotosStore()
const router = useRouter()

// DATA
const creating = ref(false)

// COMPUTED
const userId = computed(() => props.view.profile.id)
const isSelf = computed(() => props.view.friendship === 'self')
const state = computed(() => photos.albumsByUser[userId.value] ?? { status: 'loading', ids: [], error: null })
const albums = computed(() => state.value.ids.map((id) => photos.albums[id]).filter(Boolean))

// METHODS
const load = () => photos.loadAlbums(userId.value)
const onCreated = (album) => router.push({ name: 'album', params: { id: album.id } })

// LIFECYCLE
onMounted(load)
</script>

<template>
  <section class="panel profile-albums" aria-labelledby="albums-title">
    <div class="profile-albums__head">
      <h2 id="albums-title" class="panel-title profile-albums__title">{{ isSelf ? 'Mis álbumes' : `Álbumes de ${view.profile.firstName}` }}</h2>
      <button v-if="isSelf" type="button" class="btn btn--soft btn--sm" @click="creating = true">
        <Plus aria-hidden="true" />
        Nuevo álbum
      </button>
    </div>
    <AsyncState :status="state.status" :error="state.error" :empty="!albums.length" skeleton="grid" :skeleton-count="6" @retry="load">
      <template #empty>
        <StateMessage :icon="Images" title="Todavía no hay álbumes." :text="isSelf ? 'Crea uno y sube las fotos del último plan.' : ''" />
      </template>
      <AlbumGrid :albums="albums" label="Álbumes" />
    </AsyncState>
    <AlbumFormDialog v-if="isSelf" :open="creating" @close="creating = false" @saved="onCreated" />
  </section>
</template>

<style lang="scss" scoped>
.profile-albums {
  &__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: $space-3;
    padding: $space-3 $space-4 0;
  }

  // Same light subheading as the other profile tabs, next to its button.
  &__title {
    padding: 0;
    background: none;
    border: 0;
    color: $color-text-muted;
  }
}
</style>
