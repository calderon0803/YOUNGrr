<script setup>
import { computed, ref, useId } from 'vue'
import { ImagePlus, X } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import EmojiPicker from '@/components/common/EmojiPicker.vue'
import MentionMenu from '@/components/common/MentionMenu.vue'
import { useAuthStore } from '@/stores/auth'
import { useGroupsStore } from '@/stores/groups'
import { useToast } from '@/composables/useToast'
import { useImagePicker } from '@/composables/useImagePicker'
import { useEmojiInsert } from '@/composables/useEmojiInsert'
import { useMentions } from '@/composables/useMentions'
import { errorMessage } from '@/services/errors'
import { ACCEPTED_IMAGE_TYPES } from '@/utils/image'
import { LIMITS } from '@/utils/validation'

// Writes in the Gallinero: a short text (as a tweet) and, optionally, one photo.
// "@" mentions the people of the group.

// PROPS
const props = defineProps({
  groupId: { type: String, required: true },
})

// STORES
const auth = useAuthStore()
const groups = useGroupsStore()
const toast = useToast()

// DATA
const text = ref('')
const photo = ref(null)
const sending = ref(false)
const input = ref(null)
const fileInput = ref(null)
const inputId = useId()
const counterId = useId()
const { processing, read } = useImagePicker()
const { insert: addEmoji } = useEmojiInsert(input, text, () => LIMITS.groupPost)
const mention = useMentions(input, text, () => (groups.details[props.groupId]?.members ?? []).map((m) => m.person).filter((p) => p.id !== auth.meId))

// COMPUTED
const left = computed(() => LIMITS.groupPost - text.value.length)
const canSend = computed(() => (text.value.trim().length > 0 || !!photo.value) && left.value >= 0 && !sending.value && !processing.value)

// METHODS
const pickPhoto = async (event) => {
  const [image] = await read([...event.target.files].slice(0, 1))
  event.target.value = ''
  if (image) photo.value = image
}

const send = async () => {
  if (!canSend.value) return
  sending.value = true
  try {
    await groups.createPost(props.groupId, { text: text.value, photo: photo.value, mentions: mention.mentions.value })
    text.value = ''
    photo.value = null
    mention.reset()
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <form class="composer" @submit.prevent="send">
    <UserAvatar :person="auth.me" size="sm" />
    <div class="composer__body">
      <label class="visually-hidden" :for="inputId">Escribe en el Gallinero</label>
      <div class="composer__field">
      <textarea
        :id="inputId"
        ref="input"
        v-model="text"
        class="textarea composer__input"
        rows="2"
        :maxlength="LIMITS.groupPost"
        placeholder="¿Qué se cuece en el grupo?"
        :aria-describedby="counterId"
        @input="mention.onInput"
        @click="mention.onInput"
        @keydown="mention.onKeydown"
        @blur="mention.close"
      />
      <MentionMenu :suggestions="mention.suggestions.value" :active="mention.active.value" @pick="mention.choose" />
      </div>
      <div v-if="photo" class="composer__preview">
        <img :src="photo.dataUrl" alt="Foto que vas a publicar" />
        <button type="button" class="composer__remove" aria-label="Quitar la foto" @click="photo = null">
          <X aria-hidden="true" />
        </button>
      </div>
      <div class="composer__actions">
        <input ref="fileInput" class="visually-hidden" type="file" :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="pickPhoto" />
        <button type="button" class="btn btn--ghost btn--sm" :disabled="processing || !!photo" @click="fileInput?.click()">
          <ImagePlus aria-hidden="true" />
          {{ processing ? 'Revisando…' : 'Foto' }}
        </button>
        <EmojiPicker @pick="addEmoji" />
        <span :id="counterId" class="composer__counter" :class="{ 'composer__counter--low': left < 20 }">{{ left }}</span>
        <button type="submit" class="btn btn--primary btn--sm" :disabled="!canSend">
          {{ sending ? 'Publicando…' : 'Publicar' }}
        </button>
      </div>
    </div>
  </form>
</template>

<style lang="scss" scoped>
.composer {
  display: flex;
  align-items: flex-start;
  gap: $space-2;
  padding: $space-3;
  border-bottom: 1px solid $color-border;

  &__body {
    display: flex;
    flex: 1;
    flex-direction: column;
    gap: $space-2;
    min-width: 0;
  }

  &__field {
    position: relative;
  }

  &__input {
    width: 100%;
    resize: vertical;
  }

  &__preview {
    position: relative;
    align-self: flex-start;

    img {
      display: block;
      max-width: 100%;
      max-height: 12rem;
      border-radius: $radius-sm;
    }
  }

  &__remove {
    @include reset-button;
    position: absolute;
    top: $space-1;
    right: $space-1;
    display: grid;
    place-items: center;
    width: 1.75rem;
    height: 1.75rem;
    border-radius: $radius-pill;
    background: $color-overlay;
    color: $color-viewer-text;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }

  &__actions {
    display: flex;
    align-items: center;
    gap: $space-2;
  }

  &__counter {
    margin-left: auto;
    font-size: $fs-sm;
    color: $color-text-muted;

    &--low {
      color: $color-danger;
    }
  }
}
</style>
