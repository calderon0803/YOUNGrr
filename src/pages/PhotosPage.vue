<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Images, Plus } from 'lucide-vue-next'
import TabNav from '@/components/common/TabNav.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import AlbumGrid from '@/components/photos/AlbumGrid.vue'
import PhotoGrid from '@/components/photos/PhotoGrid.vue'
import AlbumFormDialog from '@/components/photos/AlbumFormDialog.vue'
import { usePhotosStore } from '@/stores/photos'
import { useAuthStore } from '@/stores/auth'

// STORES
const route = useRoute()
const router = useRouter()
const photos = usePhotosStore()
const auth = useAuthStore()

// DATA
const creating = ref(false)
const TABS = [
  { key: 'albums', label: 'Mis álbumes' },
  { key: 'friends', label: 'De tus amigos' },
]

// COMPUTED
const tab = computed(() => (route.query.tab === 'friends' ? 'friends' : 'albums'))
const albumsState = computed(() => photos.albumsByUser[auth.meId] ?? { status: 'loading', ids: [], error: null })
const albums = computed(() => albumsState.value.ids.map((id) => photos.albums[id]).filter(Boolean))
const friendsState = computed(() => photos.lists.friends ?? { status: 'loading', ids: [], error: null })

// METHODS
const tabRoute = (key) => ({ query: key === 'albums' ? {} : { tab: key } })
const load = () => (tab.value === 'albums' ? photos.loadAlbums(auth.meId) : photos.loadFriendsPhotos())
const onCreated = (album) => router.push({ name: 'album', params: { id: album.id } })

// LIFECYCLE
onMounted(load)

// WATCHERS
watch(tab, load)
</script>

<template>
  <div class="photos-page">
    <div class="photos-page__head">
      <h1 class="page-title">Fotos</h1>
      <button type="button" class="btn btn--primary" @click="creating = true">
        <Plus aria-hidden="true" />
        Nuevo álbum
      </button>
    </div>

    <div class="panel photos-page__panel">
      <TabNav label="Secciones de fotos" :tabs="TABS" :active="tab" :to="tabRoute" />

      <AsyncState v-if="tab === 'albums'" :status="albumsState.status" :error="albumsState.error" :empty="!albums.length" skeleton="grid" :skeleton-count="6" @retry="load">
        <template #empty>
          <StateMessage :icon="Images" title="Todavía no tienes álbumes." text="Crea tu primer álbum y sube las fotos del último plan.">
            <button type="button" class="btn btn--primary" @click="creating = true">Crear álbum</button>
          </StateMessage>
        </template>
        <AlbumGrid :albums="albums" label="Mis álbumes" />
      </AsyncState>

      <AsyncState v-else :status="friendsState.status" :error="friendsState.error" :empty="!friendsState.ids.length" skeleton="grid" :skeleton-count="10" @retry="load">
        <template #empty>
          <StateMessage :icon="Images" title="Tus amigos todavía no han subido fotos." />
        </template>
        <PhotoGrid :ids="friendsState.ids" label="Fotos recientes de tus amigos" />
      </AsyncState>
    </div>

    <AlbumFormDialog :open="creating" @close="creating = false" @saved="onCreated" />
  </div>
</template>

<style lang="scss" scoped>
.photos-page {
  &__head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: $space-3;
    padding: 0 $space-4;
  }

  &__panel {
    overflow: hidden;
    border-radius: 0;
    border-right: 0;
    border-left: 0;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .photos-page {
    &__head {
      padding: 0;
    }

    &__panel {
      border-right: 1px solid $color-border;
      border-left: 1px solid $color-border;
      border-radius: $radius;
    }
  }
}
</style>
