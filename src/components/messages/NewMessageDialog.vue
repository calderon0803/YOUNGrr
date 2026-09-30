<script setup>
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import BaseModal from '@/components/common/BaseModal.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import FriendPicker from '@/components/events/FriendPicker.vue'
import { useAuthStore } from '@/stores/auth'
import { useFriendsStore } from '@/stores/friends'
import { useMessagesStore } from '@/stores/messages'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { fullName, matches } from '@/utils/text'
import { LIMITS } from '@/utils/validation'
import { GROUP_CHAT_MAX } from '@/config/app'

// A new chat: with one friend, or a named group with several of them.

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
/** 'direct' (one friend) or 'group'. */
const mode = ref('direct')
const title = ref('')
const people = ref([])
const creating = ref(false)
const error = ref('')

// COMPUTED
const state = computed(() => friends.lists[auth.meId] ?? { status: 'loading', items: [] })
const options = computed(() => state.value.items.filter((p) => !query.value.trim() || matches(fullName(p), query.value)))
const canCreate = computed(() => title.value.trim() && people.value.length >= 2 && people.value.length < GROUP_CHAT_MAX && !creating.value)

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

const createGroup = async () => {
  if (!canCreate.value) return
  creating.value = true
  error.value = ''
  try {
    const id = await messages.createGroupChat(title.value, people.value)
    emit('close')
    router.push({ name: 'conversation', params: { id } })
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    creating.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    query.value = ''
    mode.value = 'direct'
    title.value = ''
    people.value = []
    error.value = ''
    friends.loadFriends(auth.meId)
  },
)
</script>

<template>
  <BaseModal :open="open" title="Nuevo mensaje" size="sm" :busy="creating" @close="emit('close')">
    <div class="new-message__modes" role="group" aria-label="Tipo de conversación">
      <button type="button" class="btn btn--sm" :class="mode === 'direct' ? 'btn--primary' : 'btn--secondary'" :aria-pressed="mode === 'direct'" @click="mode = 'direct'">Un amigo</button>
      <button type="button" class="btn btn--sm" :class="mode === 'group' ? 'btn--primary' : 'btn--secondary'" :aria-pressed="mode === 'group'" @click="mode = 'group'">Grupo</button>
    </div>

    <form v-if="mode === 'group'" class="new-message__group" @submit.prevent="createGroup">
      <label class="field">
        <span class="field__label">Nombre del grupo</span>
        <input v-model="title" class="input" :maxlength="LIMITS.groupChatTitle" placeholder="Cena del viernes" required />
      </label>
      <FriendPicker v-model="people" label="Amigos a los que invitar" />
      <p class="new-message__hint">Al menos 2 amigos, hasta {{ GROUP_CHAT_MAX }} personas contigo. Les llegará una invitación.</p>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
      <button type="submit" class="btn btn--primary" :disabled="!canCreate">{{ creating ? 'Creando…' : 'Crear grupo' }}</button>
    </form>

    <template v-else>
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
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.new-message {
  &__modes {
    display: flex;
    gap: $space-2;
    margin-bottom: $space-3;
  }

  &__group {
    display: flex;
    flex-direction: column;
    gap: $space-3;
  }

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
