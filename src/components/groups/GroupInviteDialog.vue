<script setup>
import { computed, ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import FriendPicker from '@/components/events/FriendPicker.vue'
import { useGroupsStore } from '@/stores/groups'
import { errorMessage } from '@/services/errors'

// Members invite their friends; each one accepts or declines.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  groupId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const groups = useGroupsStore()

// DATA
const selected = ref([])
const sending = ref(false)
const error = ref('')

// COMPUTED
const already = computed(() => (groups.details[props.groupId]?.members ?? []).map((m) => m.person.id))

// METHODS
const send = async () => {
  sending.value = true
  error.value = ''
  try {
    await groups.invite(props.groupId, selected.value)
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
  (open) => {
    if (!open) return
    selected.value = []
    error.value = ''
  },
)
</script>

<template>
  <BaseModal :open="open" title="Invitar amigos al grupo" :busy="sending" @close="emit('close')">
    <FriendPicker v-model="selected" :excluded="already" excluded-label="Ya está" />
    <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="sending" @click="emit('close')">Cancelar</button>
      <button type="button" class="btn btn--primary" :disabled="!selected.length || sending" @click="send">
        {{ sending ? 'Enviando…' : 'Enviar invitaciones' }}
      </button>
    </template>
  </BaseModal>
</template>
