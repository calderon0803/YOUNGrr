<script setup>
import { computed, ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import FriendPicker from '@/components/events/FriendPicker.vue'
import { useEventsStore } from '@/stores/events'
import { errorMessage } from '@/services/errors'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  event: { type: Object, required: true },
})

const emit = defineEmits(['close'])

// STORES
const events = useEventsStore()

// DATA
const selected = ref([])
const sending = ref(false)
const error = ref('')

// COMPUTED
const already = computed(() => props.event.members.map((m) => m.person.id))

// METHODS
const send = async () => {
  sending.value = true
  error.value = ''
  try {
    await events.invite(props.event.id, selected.value)
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
  <BaseModal :open="open" title="Invitar amigos" :busy="sending" @close="emit('close')">
    <FriendPicker v-model="selected" :excluded="already" />
    <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="sending" @click="emit('close')">Cancelar</button>
      <button type="button" class="btn btn--primary" :disabled="!selected.length || sending" @click="send">
        {{ sending ? 'Enviando…' : 'Enviar invitaciones' }}
      </button>
    </template>
  </BaseModal>
</template>
