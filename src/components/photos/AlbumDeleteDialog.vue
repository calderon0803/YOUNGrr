<script setup>
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import BaseModal from '@/components/common/BaseModal.vue'
import { usePhotosStore } from '@/stores/photos'
import { errorMessage } from '@/services/errors'
import { DEFAULT_ALBUM_TITLE } from '@/config/app'

// Deleting an album: only the album (its photos stay in "Mis fotos"), also the
// photos that are in no other album, or also all of them.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  album: { type: Object, required: true },
})

const emit = defineEmits(['close'])

// STORES
const router = useRouter()
const photos = usePhotosStore()

// DATA
const OPTIONS = [
  { value: 'album', label: 'Solo el álbum', hint: `Las fotos siguen en ${DEFAULT_ALBUM_TITLE} y en tus otros álbumes.` },
  { value: 'exclusive', label: 'El álbum y las fotos que solo están en él', hint: 'Las fotos que también están en otro álbum tuyo se quedan.' },
  { value: 'all', label: 'El álbum y todas sus fotos', hint: 'Se borran de todos tus álbumes, con sus comentarios, Grr y etiquetas.' },
]
const mode = ref('album')
const deleting = ref(false)
const error = ref('')

// METHODS
const remove = async () => {
  deleting.value = true
  error.value = ''
  // The album page goes away with the album (and this dialog with it): keep
  // the owner and go back to their albums from here.
  const ownerId = props.album.ownerId
  try {
    await photos.deleteAlbum(props.album.id, mode.value)
    router.replace({ name: 'profile', params: { id: ownerId }, query: { tab: 'albums' } })
  } catch (e) {
    error.value = errorMessage(e)
    deleting.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    mode.value = 'album'
    error.value = ''
    deleting.value = false
  },
)
</script>

<template>
  <BaseModal :open="open" :title="`Eliminar «${album.title}»`" :busy="deleting" @close="emit('close')">
    <fieldset class="delete">
      <legend class="delete__legend">¿Qué quieres eliminar?</legend>
      <label v-for="option in OPTIONS" :key="option.value" class="delete__option">
        <input v-model="mode" type="radio" name="album-delete" :value="option.value" />
        <span>
          <strong>{{ option.label }}</strong>
          <span class="delete__hint">{{ option.hint }}</span>
        </span>
      </label>
    </fieldset>
    <p class="delete__note">Las fotos compartidas con otros dueños siguen en su perfil. No se puede deshacer.</p>
    <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="deleting" @click="emit('close')">Cancelar</button>
      <button type="button" class="btn btn--danger" :disabled="deleting" @click="remove">{{ deleting ? 'Eliminando…' : 'Eliminar' }}</button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.delete {
  display: flex;
  flex-direction: column;
  gap: $space-2;
  margin: 0;
  padding: 0;
  border: 0;

  &__legend {
    margin-bottom: $space-2;
    font-weight: 700;
  }

  &__option {
    display: flex;
    align-items: flex-start;
    gap: $space-2;
    padding: $space-2 $space-3;
    border: 1px solid $color-border;
    border-radius: $radius-sm;
    cursor: pointer;

    input {
      flex-shrink: 0;
      margin-top: 0.25rem;
      accent-color: $color-brand;
    }

    &:has(input:checked) {
      border-color: $color-brand;
      background: $color-brand-tint;
    }
  }

  &__hint {
    display: block;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__note {
    margin-top: $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
