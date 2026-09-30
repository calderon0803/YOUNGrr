<script setup>
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import BaseModal from '@/components/common/BaseModal.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import FriendPicker from '@/components/events/FriendPicker.vue'
import { useMessagesStore } from '@/stores/messages'
import { useAuthStore } from '@/stores/auth'
import { useConfirm } from '@/composables/useConfirm'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'
import { GROUP_CHAT_MAX } from '@/config/app'

// A group chat's people. Its creator renames it, invites friends (they join
// only if they accept) and removes people; anyone can leave (the creator's role
// then goes to the oldest member).

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  conversationId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const messages = useMessagesStore()
const auth = useAuthStore()
const router = useRouter()
const { confirm } = useConfirm()

// DATA
const title = ref('')
const adding = ref([])
const busy = ref(false)
const error = ref('')

// COMPUTED
const conversation = computed(() => messages.threads[props.conversationId]?.conversation ?? null)
const isCreator = computed(() => conversation.value?.createdById === auth.meId)
const members = computed(() => conversation.value?.members ?? [])
const invited = computed(() => conversation.value?.invited ?? [])
const room = computed(() => GROUP_CHAT_MAX - members.value.length - invited.value.length)

// METHODS
const run = async (action) => {
  busy.value = true
  error.value = ''
  try {
    await action()
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    busy.value = false
  }
}

const rename = () => run(() => messages.renameGroupChat(props.conversationId, title.value))

const add = () =>
  run(async () => {
    await messages.addToGroupChat(props.conversationId, adding.value)
    adding.value = []
  })

const remove = async (person) => {
  const ok = await confirm({ title: 'Quitar del grupo', message: `${person.firstName} dejará de estar en el grupo y de ver sus mensajes nuevos.`, confirmLabel: 'Quitar', danger: true })
  if (ok) messages.removeFromGroupChat(props.conversationId, person.id)
}

const leave = async () => {
  const ok = await confirm({ title: 'Salir del grupo', message: 'Dejarás de ver sus mensajes. Para volver, alguien tendrá que añadirte.', confirmLabel: 'Salir', danger: true })
  if (!ok) return
  if (await messages.leaveGroupChat(props.conversationId)) {
    emit('close')
    router.push({ name: 'messages' })
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    title.value = conversation.value?.title ?? ''
    adding.value = []
    error.value = ''
  },
)
</script>

<template>
  <BaseModal :open="open" :title="conversation?.title ?? 'Grupo'" :busy="busy" @close="emit('close')">
    <div class="group-chat">
      <form v-if="isCreator" class="group-chat__rename" @submit.prevent="rename">
        <label class="field">
          <span class="field__label">Nombre del grupo</span>
          <input v-model="title" class="input" :maxlength="LIMITS.groupChatTitle" required />
        </label>
        <button type="submit" class="btn btn--secondary btn--sm" :disabled="busy || !title.trim() || title.trim() === conversation?.title">Cambiar</button>
      </form>

      <section>
        <h3 class="group-chat__heading">{{ members.length }} personas</h3>
        <ul class="group-chat__members" role="list">
          <li v-for="person in members" :key="person.id" class="group-chat__member">
            <UserAvatar :person="person" size="sm" />
            <PersonLink :person="person" @click="emit('close')" />
            <span v-if="person.id === conversation?.createdById" class="group-chat__tag">Creador</span>
            <button
              v-if="isCreator && person.id !== auth.meId"
              type="button"
              class="group-chat__remove"
              @click="remove(person)"
            >
              Quitar
            </button>
          </li>
        </ul>
      </section>

      <section v-if="invited.length">
        <h3 class="group-chat__heading">Invitados, sin responder</h3>
        <ul class="group-chat__members" role="list">
          <li v-for="person in invited" :key="person.id" class="group-chat__member">
            <UserAvatar :person="person" size="sm" />
            <PersonLink :person="person" @click="emit('close')" />
            <button v-if="isCreator" type="button" class="group-chat__remove" @click="messages.removeFromGroupChat(conversationId, person.id)">Retirar</button>
          </li>
        </ul>
      </section>

      <form v-if="isCreator && room > 0" class="group-chat__add" @submit.prevent="add">
        <FriendPicker v-model="adding" :excluded="[...members, ...invited].map((m) => m.id)" label="Invitar a amigos" excluded-label="Ya está" />
        <button type="submit" class="btn btn--secondary btn--sm" :disabled="busy || !adding.length || adding.length > room">Invitar</button>
      </form>

      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </div>
    <template #footer>
      <button type="button" class="btn btn--danger" :disabled="busy" @click="leave">Salir del grupo</button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.group-chat {
  display: flex;
  flex-direction: column;
  gap: $space-4;

  &__rename,
  &__add {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: $space-2;

    .field {
      width: 100%;
    }
  }

  &__heading {
    margin-bottom: $space-2;
    font-weight: 700;
  }

  &__members {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    margin: 0;
    padding: 0;
  }

  &__member {
    display: flex;
    align-items: center;
    gap: $space-2;
  }

  &__tag {
    padding: 0.05rem $space-2;
    border-radius: $radius-sm;
    background: $color-brand-tint;
    color: $color-brand-strong;
    font-size: $fs-xs;
    font-weight: 700;
  }

  &__remove {
    @include reset-button;
    margin-left: auto;
    font-size: $fs-sm;
    color: $color-danger;

    &:hover {
      text-decoration: underline;
    }
  }
}
</style>
