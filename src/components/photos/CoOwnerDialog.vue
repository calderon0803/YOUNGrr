<script setup>
import { computed, ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import FriendPicker from '@/components/events/FriendPicker.vue'
import { usePhotosStore } from '@/stores/photos'
import { errorMessage } from '@/services/errors'

// Invites friends to co-own a photo: once they accept, same rights as the uploader.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  photo: { type: Object, required: true },
})

const emit = defineEmits(['close'])

// STORES
const photos = usePhotosStore()

// DATA
const selected = ref([])
const sending = ref(false)
const error = ref('')

// COMPUTED
const taken = computed(() => [...props.photo.owners, ...props.photo.pendingOwners].map((p) => p.id))

// METHODS
const send = async () => {
  sending.value = true
  error.value = ''
  try {
    await photos.inviteCoOwners(props.photo.id, selected.value)
    emit('close')
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    sending.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => open && (selected.value = []),
)
</script>

<template>
  <BaseModal :open="open" title="Compartir la foto" :busy="sending" @close="emit('close')">
    <p class="co-owner__hint">
      Las personas que aceptes serán dueñas de la foto igual que tú: podrán etiquetar, editar el pie y la verán en su perfil.
    </p>
    <FriendPicker v-model="selected" :excluded="taken" label="¿Con quién la compartes?" excluded-label="Ya es dueño o está invitado" />
    <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="sending" @click="emit('close')">Cancelar</button>
      <button type="button" class="btn btn--primary" :disabled="!selected.length || sending" @click="send">
        {{ sending ? 'Enviando…' : 'Enviar invitación' }}
      </button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.co-owner__hint {
  margin-bottom: $space-4;
  color: $color-text-muted;
}
</style>
