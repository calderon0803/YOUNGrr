<script setup>
import { computed, onMounted, ref, useId } from 'vue'
import { MessageSquareText } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import ReportDialog from '@/components/feed/ReportDialog.vue'
import { useAuthStore } from '@/stores/auth'
import { useWallStore } from '@/stores/wall'
import { useConfirm } from '@/composables/useConfirm'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'

// Profile wall ("tablón"): messages the owner's friends leave on the profile.

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

// STORES
const auth = useAuthStore()
const wall = useWallStore()
const { confirm } = useConfirm()
const toast = useToast()

// DATA
const text = ref('')
/** Id of the wall message being reported. */
const reportingId = ref(null)
const sending = ref(false)
const inputId = useId()

// COMPUTED
const profileId = computed(() => props.view.profile.id)
const state = computed(() => wall.walls[profileId.value] ?? { status: 'loading', error: null, errorCode: null, messages: [], canWrite: false })
const isSelf = computed(() => props.view.friendship === 'self')
const placeholder = computed(() => (isSelf.value ? 'Escribe algo en tu tablón...' : `Escribe algo en el tablón de ${props.view.profile.firstName}...`))

// METHODS
const canDelete = (message) => message.authorId === auth.meId || isSelf.value

const send = async () => {
  if (!text.value.trim() || sending.value) return
  sending.value = true
  try {
    await wall.addMessage(profileId.value, text.value)
    text.value = ''
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    sending.value = false
  }
}

const remove = async (messageId) => {
  const ok = await confirm({ title: 'Borrar mensaje', message: 'Desaparecerá del tablón.', confirmLabel: 'Borrar', danger: true })
  if (ok) wall.deleteMessage(profileId.value, messageId)
}

// LIFECYCLE
onMounted(() => wall.loadWall(profileId.value))
</script>

<template>
  <div class="wall">
    <form v-if="state.canWrite" class="wall__form" @submit.prevent="send">
      <label class="visually-hidden" :for="inputId">{{ placeholder }}</label>
      <textarea :id="inputId" v-model="text" class="textarea wall__input" rows="2" :placeholder="placeholder" :maxlength="LIMITS.wallText" />
      <div class="wall__form-actions">
        <button type="submit" class="btn btn--primary btn--sm" :disabled="!text.trim() || sending">
          {{ sending ? 'Publicando…' : 'Publicar en el tablón' }}
        </button>
      </div>
    </form>

    <AsyncState :status="state.status" :error="state.error" :error-code="state.errorCode" :empty="!state.messages.length" @retry="wall.loadWall(profileId)">
      <template #empty>
        <StateMessage
          compact
          :icon="MessageSquareText"
          :title="isSelf ? 'Tu tablón está vacío.' : 'Nadie ha escrito todavía en este tablón.'"
          :text="isSelf ? 'Aquí aparecerá lo que te escriban tus amigos.' : state.canWrite ? 'Sé el primero en dejarle algo.' : ''"
        />
      </template>
      <ul class="wall__list" role="list" aria-label="Mensajes del tablón">
        <li v-for="message in state.messages" :key="message.id" class="wall__message">
          <UserAvatar :person="message.author" size="sm" />
          <div class="wall__body">
            <p>
              <PersonLink :person="message.author" />
              <span class="wall__text user-text">{{ message.text }}</span>
            </p>
            <p class="wall__meta">
              <RelativeTime :value="message.createdAt" />
              <template v-if="canDelete(message)">
                ·
                <button type="button" class="wall__delete" @click="remove(message.id)">Borrar</button>
              </template>
              <template v-if="message.authorId !== auth.meId">
                ·
                <button type="button" class="wall__delete" @click="reportingId = message.id">Reportar</button>
              </template>
            </p>
          </div>
        </li>
      </ul>
    </AsyncState>
    <ReportDialog v-if="reportingId" :open="!!reportingId" kind="wall_message" :target-id="reportingId" @close="reportingId = null" />
  </div>
</template>

<style lang="scss" scoped>
.wall {
  &__form {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    padding: $space-3;
    background: $color-surface-alt;
    border-bottom: 1px solid $color-border;
  }

  &__input {
    min-height: 3.5rem;
    font-size: $fs-base;
  }

  &__form-actions {
    display: flex;
    justify-content: flex-end;
  }

  &__list {
    margin: 0;
  }

  &__message {
    display: flex;
    gap: $space-3;
    padding: $space-3;

    & + & {
      border-top: 1px solid $color-border;
    }
  }

  &__body {
    min-width: 0;

    :deep(.person-link) {
      margin-right: 0.35rem;
    }
  }

  &__meta {
    margin-top: 0.15rem;
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__delete {
    @include reset-button;
    color: $color-text-muted;

    &:hover {
      color: $color-danger;
      text-decoration: underline;
    }
  }
}
</style>
