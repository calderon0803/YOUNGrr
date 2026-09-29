<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ImagePlus, Plus } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import PhotoGrid from '@/components/photos/PhotoGrid.vue'
import AlbumFormDialog from '@/components/photos/AlbumFormDialog.vue'
import PhotoUploadDialog from '@/components/photos/PhotoUploadDialog.vue'
import AlbumAddPhotosDialog from '@/components/photos/AlbumAddPhotosDialog.vue'
import AlbumDeleteDialog from '@/components/photos/AlbumDeleteDialog.vue'
import { usePhotosStore } from '@/stores/photos'
import { useOwnerRedirect } from '@/composables/useOwnerRedirect'
import { fullDate } from '@/utils/time'
import { plural } from '@/utils/text'
import { DEFAULT_ALBUM_TITLE } from '@/config/app'

// STORES
const route = useRoute()
const photos = usePhotosStore()
const { redirectToOwner } = useOwnerRedirect()

// DATA
const editing = ref(false)
const uploading = ref(false)
const adding = ref(false)
const deleting = ref(false)

// COMPUTED
const albumId = computed(() => String(route.params.id))
const state = computed(() => photos.albumDetail[albumId.value] ?? { status: 'loading', ids: [], error: null, errorCode: null, canEdit: false })
const album = computed(() => photos.albums[albumId.value])
const isWall = computed(() => album.value?.kind === 'wall')
const menuItems = computed(() => [
  { key: 'edit', label: 'Editar álbum' },
  { key: 'delete', label: 'Eliminar álbum', danger: true },
])

// METHODS
const onMenu = (key) => {
  if (key === 'edit') editing.value = true
  else deleting.value = true
}

const openFromQuery = () => {
  const photoId = route.query.photo
  if (typeof photoId === 'string' && state.value.ids.includes(photoId) && !photos.viewer.open) {
    photos.openViewer(state.value.ids, state.value.ids.indexOf(photoId))
  }
}

// WATCHERS
watch(
  albumId,
  async (id) => {
    await photos.loadAlbum(id)
    if (redirectToOwner(state.value.errorCode, state.value.errorOwnerId)) return
    openFromQuery()
  },
  { immediate: true },
)

watch(() => route.query.photo, openFromQuery)
</script>

<template>
  <div class="album-page">
    <AsyncState
      :status="state.status"
      :error="state.error"
      :error-code="state.errorCode"
      skeleton="grid"
      :skeleton-count="10"
      @retry="photos.loadAlbum(albumId)"
    >
      <template v-if="album">
        <header class="album-page__header panel">
          <div class="album-page__text">
            <p class="album-page__owner">
              <UserAvatar :person="album.owner" size="xs" />
              <PersonLink :person="album.owner" />
            </p>
            <h1 class="album-page__title">{{ isWall ? DEFAULT_ALBUM_TITLE : album.title }}</h1>
            <p v-if="album.description" class="album-page__description user-text">{{ album.description }}</p>
            <p class="album-page__meta">{{ plural(album.photoCount, 'foto', 'fotos') }} · Actualizado el {{ fullDate(album.updatedAt) }}</p>
          </div>
          <div v-if="state.canEdit" class="album-page__actions">
            <!-- Photos are uploaded to "Mis fotos" and added from there to the other albums. -->
            <button v-if="isWall" type="button" class="btn btn--primary" @click="uploading = true">
              <ImagePlus aria-hidden="true" />
              Subir fotografías
            </button>
            <button v-else type="button" class="btn btn--primary" @click="adding = true">
              <Plus aria-hidden="true" />
              Añadir fotos
            </button>
            <DropdownMenu v-if="!isWall" label="Opciones del álbum" :items="menuItems" @select="onMenu" />
          </div>
        </header>

        <section class="panel album-page__photos" aria-label="Fotografías del álbum">
          <PhotoGrid v-if="state.ids.length" :ids="state.ids" :label="`Fotografías de ${album.title}`" />
          <StateMessage v-else title="Este álbum está vacío." :text="state.canEdit ? (isWall ? 'Sube tus primeras fotografías.' : 'Añade fotos que ya hayas subido.') : ''">
            <button v-if="state.canEdit && isWall" type="button" class="btn btn--primary" @click="uploading = true">Subir fotografías</button>
            <button v-else-if="state.canEdit" type="button" class="btn btn--primary" @click="adding = true">Añadir fotos</button>
          </StateMessage>
        </section>

        <PhotoUploadDialog v-if="state.canEdit && isWall" :open="uploading" @close="uploading = false" />
        <template v-if="state.canEdit && !isWall">
          <AlbumFormDialog :open="editing" :album="album" @close="editing = false" />
          <AlbumAddPhotosDialog :open="adding" :album-id="album.id" @close="adding = false" />
          <AlbumDeleteDialog :open="deleting" :album="album" @close="deleting = false" />
        </template>
      </template>
    </AsyncState>
  </div>
</template>

<style lang="scss" scoped>
.album-page {
  display: flex;
  flex-direction: column;
  gap: $space-3;

  &__header {
    display: flex;
    flex-direction: column;
    gap: $space-3;
    padding: $space-4;
    border-top: 3px solid $color-grr;
  }

  &__owner {
    display: flex;
    align-items: center;
    gap: $space-2;
    font-size: $fs-sm;
  }

  &__title {
    margin-top: $space-2;
    font-size: $fs-xl;
    font-weight: 800;
  }

  &__description {
    max-width: 40rem;
    margin-top: $space-1;
  }

  &__meta {
    margin-top: $space-2;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__actions {
    display: flex;
    align-items: center;
    gap: $space-2;
  }

  &__photos {
    overflow: hidden;
    padding: $space-3;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .album-page__header {
    flex-direction: row;
    align-items: flex-start;
    justify-content: space-between;
  }
}
</style>
