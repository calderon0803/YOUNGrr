<script setup>
import { computed, ref } from 'vue'
import { ImagePlus, X } from 'lucide-vue-next'
import RelativeTime from '@/components/common/RelativeTime.vue'
import { useFeedStore } from '@/stores/feed'
import { useImagePicker } from '@/composables/useImagePicker'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { ACCEPTED_IMAGE_TYPES } from '@/utils/image'
import { LIMITS } from '@/utils/validation'

// Tuenti's status box: one line "¿Qué estás haciendo?". A text-only post becomes
// your current status; with a photo it is published as a photo.

// PROPS
defineProps({
  /** { text, createdAt } of your current status, shown under the box. */
  status: { type: Object, default: null },
})

const emit = defineEmits(['published'])

// STORES
const feed = useFeedStore()
const toast = useToast()

// DATA
const text = ref('')
const photo = ref(null)
const fileInput = ref(null)
const textarea = ref(null)
const submitting = ref(false)
const { processing, read } = useImagePicker()

// COMPUTED
const remaining = computed(() => LIMITS.postText - text.value.length)
const dirty = computed(() => text.value.trim().length > 0 || photo.value !== null)
const canSubmit = computed(() => dirty.value && remaining.value >= 0 && !submitting.value && !processing.value)

// METHODS
const autoGrow = () => {
  const el = textarea.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = `${Math.min(el.scrollHeight, 200)}px`
}

const pickPhoto = async (event) => {
  const [result] = await read([...event.target.files].slice(0, 1))
  if (result) photo.value = result
  event.target.value = ''
}

const reset = () => {
  text.value = ''
  photo.value = null
  requestAnimationFrame(autoGrow)
}

const submit = async () => {
  if (!canSubmit.value) return
  submitting.value = true
  try {
    const post = await feed.createPost({ text: text.value, photo: photo.value })
    emit('published', post)
    reset()
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    submitting.value = false
  }
}

const onKeydown = (event) => {
  // Enter publishes, like a status box; Shift+Enter adds a line.
  if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
    event.preventDefault()
    submit()
  }
}
</script>

<template>
  <section class="status-box panel" aria-labelledby="composer-title">
    <h2 class="panel-title">
      <label id="composer-title" for="composer-text">¿Qué estás haciendo?</label>
    </h2>
    <form class="status-box__form" @submit.prevent="submit">
      <textarea
        id="composer-text"
        ref="textarea"
        v-model="text"
        class="status-box__input"
        rows="1"
        placeholder="Escribe algo..."
        :maxlength="LIMITS.postText + 200"
        :aria-invalid="remaining < 0 || undefined"
        @input="autoGrow"
        @keydown="onKeydown"
      />

      <figure v-if="photo" class="status-box__preview">
        <img :src="photo.dataUrl" alt="Vista previa de la fotografía" />
        <button type="button" class="status-box__remove" aria-label="Quitar fotografía" @click="photo = null">
          <X aria-hidden="true" />
        </button>
      </figure>

      <div class="status-box__actions">
        <input ref="fileInput" class="visually-hidden" type="file" :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="pickPhoto" />
        <button type="button" class="status-box__photo" :disabled="processing || submitting" @click="fileInput?.click()">
          <ImagePlus aria-hidden="true" />
          {{ processing ? 'Preparando…' : photo ? 'Cambiar fotografía' : 'Añadir fotografía' }}
        </button>
        <span v-if="remaining < 200" class="status-box__count" :class="{ 'status-box__count--over': remaining < 0 }" aria-live="polite">
          {{ remaining }}
        </span>
        <button v-if="dirty" type="button" class="btn btn--ghost btn--sm" :disabled="submitting" @click="reset">Cancelar</button>
        <button type="submit" class="btn btn--primary btn--sm" :disabled="!canSubmit">
          {{ submitting ? 'Publicando…' : 'Publicar' }}
        </button>
      </div>
    </form>
    <p v-if="status" class="status-box__current">
      Tu estado: <span class="user-text">«{{ status.text }}»</span> · <RelativeTime :value="status.createdAt" />
    </p>
  </section>
</template>

<style lang="scss" scoped>
.status-box {
  overflow: hidden;

  &__form {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    padding: $space-3;
  }

  &__input {
    width: 100%;
    min-height: 2.125rem;
    padding: $space-2;
    border: 1px solid $color-border-strong;
    border-radius: $radius-sm;
    background: $color-surface;
    color: $color-text;
    font-size: $fs-base;
    line-height: 1.35;
    resize: none;

    &:focus-visible {
      outline: 2px solid $color-focus;
      outline-offset: -1px;
    }
  }

  &__preview {
    position: relative;
    width: fit-content;
    max-width: 100%;

    img {
      max-height: 9rem;
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
    width: 1.625rem;
    height: 1.625rem;
    border-radius: $radius-sm;
    background: $color-toast-bg;
    color: $color-toast-text;

    svg {
      width: 0.9rem;
      height: 0.9rem;
    }
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-end;
    gap: $space-2;
  }

  &__photo {
    @include reset-button;
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    margin-right: auto;
    color: $color-link;
    font-size: $fs-sm;

    svg {
      width: 1rem;
      height: 1rem;
    }

    &:hover:not(:disabled) {
      text-decoration: underline;
    }

    &:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
  }

  &__count {
    font-size: $fs-sm;
    color: $color-text-muted;

    &--over {
      color: $color-danger;
      font-weight: 700;
    }
  }

  &__current {
    padding: $space-2 $space-3;
    border-top: 1px solid $color-border;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
