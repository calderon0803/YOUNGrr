<script setup>
import { computed, ref, watch } from 'vue'
import { Images } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import { usePhotosStore } from '@/stores/photos'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/services/errors'
import { plural } from '@/utils/text'

// Adds one photo you own to one of your albums (it stays in "Mis fotos").

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  photoId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const photos = usePhotosStore()
const auth = useAuthStore()

// DATA
const saving = ref(null)
const error = ref('')

// COMPUTED
const state = computed(() => photos.albumsByUser[auth.meId] ?? { status: 'loading', ids: [], error: null })
const albums = computed(() => state.value.ids.map((id) => photos.albums[id]).filter((a) => a && a.kind === 'user'))

// METHODS
const add = async (album) => {
  saving.value = album.id
  error.value = ''
  try {
    await photos.addToAlbum(album.id, [props.photoId])
    emit('close')
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    saving.value = null
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    error.value = ''
    photos.loadAlbums(auth.meId)
  },
)
</script>

<template>
  <BaseModal :open="open" title="Añadir a un álbum" :busy="!!saving" @close="emit('close')">
    <AsyncState :status="state.status" :error="state.error" :empty="!albums.length" @retry="photos.loadAlbums(auth.meId)">
      <template #empty>
        <StateMessage compact :icon="Images" title="Todavía no tienes álbumes." text="Créalos en la pestaña Álbumes de tu perfil." />
      </template>
      <ul class="albums" role="list">
        <li v-for="album in albums" :key="album.id">
          <button type="button" class="albums__item" :disabled="!!saving" @click="add(album)">
            <span class="albums__title">{{ album.title }}</span>
            <span class="albums__meta">{{ saving === album.id ? 'Añadiendo…' : plural(album.photoCount, 'foto', 'fotos') }}</span>
          </button>
        </li>
      </ul>
    </AsyncState>
    <p v-if="error" class="field__error" role="alert">{{ error }}</p>
  </BaseModal>
</template>

<style lang="scss" scoped>
.albums {
  display: flex;
  flex-direction: column;
  gap: $space-1;
  margin: 0;
  padding: 0;

  &__item {
    @include reset-button;
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: $space-3;
    width: 100%;
    padding: $space-2 $space-3;
    border: 1px solid $color-border;
    border-radius: $radius-sm;
    text-align: left;

    &:hover:not(:disabled) {
      border-color: $color-brand;
      background: $color-brand-tint;
    }
  }

  &__title {
    font-weight: 700;
  }

  &__meta {
    flex-shrink: 0;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
