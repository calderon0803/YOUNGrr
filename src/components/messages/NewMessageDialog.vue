<script setup>
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import BaseModal from '@/components/common/BaseModal.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useAuthStore } from '@/stores/auth'
import { useFriendsStore } from '@/stores/friends'
import { useMessagesStore } from '@/stores/messages'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { fullName, matches } from '@/utils/text'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
})

const emit = defineEmits(['close'])

// STORES
const auth = useAuthStore()
const friends = useFriendsStore()
const messages = useMessagesStore()
const router = useRouter()
const toast = useToast()

// DATA
const query = ref('')
const opening = ref(null)

// COMPUTED
const state = computed(() => friends.lists[auth.meId] ?? { status: 'loading', items: [] })
const options = computed(() => state.value.items.filter((p) => !query.value.trim() || matches(fullName(p), query.value)))

// METHODS
const start = async (personId) => {
  opening.value = personId
  try {
    const id = await messages.openWith(personId)
    emit('close')
    router.push({ name: 'conversation', params: { id } })
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    opening.value = null
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    query.value = ''
    friends.loadFriends(auth.meId)
  },
)
</script>

<template>
  <BaseModal :open="open" title="Nuevo mensaje" size="sm" @close="emit('close')">
    <label class="visually-hidden" for="new-message-query">Buscar amigo</label>
    <input id="new-message-query" v-model="query" class="input" placeholder="¿A quién quieres escribir?" autocomplete="off" autofocus />
    <p v-if="state.status === 'loading' && !state.items.length" class="new-message__hint">Cargando amigos…</p>
    <p v-else-if="!state.items.length" class="new-message__hint">Solo puedes escribir a tus amigos. Añade a alguien primero.</p>
    <ul v-else class="new-message__list" role="list">
      <li v-for="person in options" :key="person.id">
        <button type="button" class="new-message__option" :disabled="opening !== null" @click="start(person.id)">
          <UserAvatar :person="person" size="sm" />
          {{ fullName(person) }}
        </button>
      </li>
    </ul>
  </BaseModal>
</template>

<style lang="scss" scoped>
.new-message {
  &__hint {
    margin-top: $space-3;
    color: $color-text-muted;
  }

  &__list {
    margin: $space-3 0 0;
  }

  &__option {
    @include reset-button;
    display: flex;
    align-items: center;
    gap: $space-3;
    width: 100%;
    padding: $space-2;
    border-radius: $radius;
    font-weight: 600;
    text-align: left;

    &:hover:not(:disabled) {
      background: $color-surface-hover;
    }
  }
}
</style>
