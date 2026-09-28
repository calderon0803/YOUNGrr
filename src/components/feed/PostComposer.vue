<script setup>
import { computed, ref } from 'vue'
import { ImagePlus, X } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useAuthStore } from '@/stores/auth'
import { useFeedStore } from '@/stores/feed'
import { useImagePicker } from '@/composables/useImagePicker'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { ACCEPTED_IMAGE_TYPES } from '@/utils/image'
import { LIMITS } from '@/utils/validation'

// STORES
const auth = useAuthStore()
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
  el.style.height = `${Math.min(el.scrollHeight, 320)}px`
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
    await feed.createPost({ text: text.value, photo: photo.value })
    reset()
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    submitting.value = false
  }
}

const onKeydown = (event) => {
  if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) submit()
}
</script>

<template>
  <section class="composer panel" aria-labelledby="composer-title">
    <form @submit.prevent="submit">
      <label id="composer-title" class="composer__title" for="composer-text">¿Qué estás haciendo?</label>
      <div class="composer__row">
        <UserAvatar class="composer__avatar" :person="auth.me" size="md" />
        <textarea
          id="composer-text"
          ref="textarea"
          v-model="text"
          class="composer__input"
          rows="2"
          placeholder="Escribe algo..."
          :maxlength="LIMITS.postText + 200"
          :aria-invalid="remaining < 0 || undefined"
          @input="autoGrow"
          @keydown="onKeydown"
        />
      </div>

      <figure v-if="photo" class="composer__preview">
        <img :src="photo.dataUrl" alt="Vista previa de la fotografía" />
        <button type="button" class="composer__remove" aria-label="Quitar fotografía" @click="photo = null">
          <X aria-hidden="true" />
        </button>
      </figure>

      <div class="composer__actions">
        <input ref="fileInput" class="visually-hidden" type="file" :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="pickPhoto" />
        <button type="button" class="btn btn--ghost" :disabled="processing || submitting" @click="fileInput?.click()">
          <ImagePlus aria-hidden="true" />
          {{ processing ? 'Preparando…' : photo ? 'Cambiar fotografía' : 'Añadir fotografía' }}
        </button>
        <span v-if="remaining < 200" class="composer__count" :class="{ 'composer__count--over': remaining < 0 }" aria-live="polite">
          {{ remaining }}
        </span>
        <button v-if="dirty" type="button" class="btn btn--ghost" :disabled="submitting" @click="reset">Cancelar</button>
        <button type="submit" class="btn btn--primary" :disabled="!canSubmit">
          {{ submitting ? 'Publicando…' : 'Publicar' }}
        </button>
      </div>
    </form>
  </section>
</template>

<style lang="scss" scoped>
.composer {
  padding: $space-3 $space-4 $space-3;
  border-top: 3px solid $color-brand;

  &__title {
    display: block;
    margin-bottom: $space-2;
    font-family: $font-display;
    font-size: $fs-md;
    font-weight: 700;
    color: $color-brand-strong;
  }

  &__row {
    display: flex;
    gap: $space-3;
  }

  &__avatar {
    display: none;
  }

  &__input {
    flex: 1;
    min-height: 3.25rem;
    padding: $space-2 $space-3;
    border: 1px solid $color-border-strong;
    border-radius: $radius;
    background: $color-surface-alt;
    color: $color-text;
    font-size: $fs-md;
    line-height: 1.4;
    resize: none;

    &:focus-visible {
      outline: 2px solid $color-focus;
      outline-offset: -1px;
      background: $color-surface;
    }
  }

  &__preview {
    position: relative;
    width: fit-content;
    max-width: 100%;
    margin-top: $space-3;

    img {
      max-height: 18rem;
      border-radius: $radius;
    }
  }

  &__remove {
    @include reset-button;
    position: absolute;
    top: $space-2;
    right: $space-2;
    display: grid;
    place-items: center;
    width: 2rem;
    height: 2rem;
    border-radius: $radius;
    background: $color-toast-bg;
    color: $color-toast-text;

    svg {
      width: 1.1rem;
      height: 1.1rem;
    }
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-end;
    gap: $space-2;
    margin-top: $space-3;

    > .btn:first-of-type {
      margin-right: auto;
      padding-left: $space-2;
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
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .composer {
    &__avatar {
      display: inline-flex;
    }

    &__actions {
      padding-left: 3.25rem;
    }
  }
}
</style>
