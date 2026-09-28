<script setup>
import { ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { useFeedStore } from '@/stores/feed'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  post: { type: Object, required: true },
})

const emit = defineEmits(['close'])

// STORES
const feed = useFeedStore()

// DATA
const text = ref('')
const saving = ref(false)
const error = ref('')

// METHODS
const save = async () => {
  saving.value = true
  error.value = ''
  try {
    await feed.updatePost(props.post.id, text.value)
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
    if (open) {
      text.value = props.post.text
      error.value = ''
    }
  },
  { immediate: true },
)
</script>

<template>
  <BaseModal :open="open" title="Editar publicación" :busy="saving" @close="emit('close')">
    <form id="edit-post-form" class="form-grid" @submit.prevent="save">
      <div class="field">
        <label class="visually-hidden" for="edit-post-text">Texto de la publicación</label>
        <textarea id="edit-post-text" v-model="text" class="textarea" rows="5" :maxlength="LIMITS.postText" autofocus />
        <p class="field__hint">{{ LIMITS.postText - text.length }} caracteres disponibles</p>
      </div>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="saving" @click="emit('close')">Cancelar</button>
      <button type="submit" form="edit-post-form" class="btn btn--primary" :disabled="saving">
        {{ saving ? 'Guardando…' : 'Guardar' }}
      </button>
    </template>
  </BaseModal>
</template>
