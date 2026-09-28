<script setup>
import { reactive, ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { usePhotosStore } from '@/stores/photos'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  /** Album to edit; null to create a new one. */
  album: { type: Object, default: null },
})

const emit = defineEmits(['close', 'saved'])

// STORES
const photos = usePhotosStore()

// DATA
const form = reactive({ title: '', description: '' })
const saving = ref(false)
const error = ref('')

// METHODS
const save = async () => {
  saving.value = true
  error.value = ''
  try {
    if (props.album) {
      await photos.updateAlbum(props.album.id, { ...form })
      emit('saved', props.album)
    } else {
      emit('saved', await photos.createAlbum({ ...form }))
    }
    emit('close')
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    saving.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    form.title = props.album?.title ?? ''
    form.description = props.album?.description ?? ''
    error.value = ''
  },
  { immediate: true },
)
</script>

<template>
  <BaseModal :open="open" :title="album ? 'Editar álbum' : 'Nuevo álbum'" size="sm" :busy="saving" @close="emit('close')">
    <form id="album-form" class="form-grid" novalidate @submit.prevent="save">
      <div class="field">
        <label class="field__label" for="album-title">Nombre</label>
        <input id="album-title" v-model="form.title" class="input" :maxlength="LIMITS.albumTitle" placeholder="Verano 2026" required autofocus />
      </div>
      <div class="field">
        <label class="field__label" for="album-description">Descripción <span class="muted">(opcional)</span></label>
        <textarea id="album-description" v-model="form.description" class="textarea" rows="3" :maxlength="LIMITS.albumDescription" />
      </div>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="saving" @click="emit('close')">Cancelar</button>
      <button type="submit" form="album-form" class="btn btn--primary" :disabled="saving || !form.title.trim()">
        {{ saving ? 'Guardando…' : album ? 'Guardar' : 'Crear álbum' }}
      </button>
    </template>
  </BaseModal>
</template>
