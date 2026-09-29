<script setup>
import { computed, ref, watch } from 'vue'
import { ImagePlus, X } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import FriendPicker from '@/components/events/FriendPicker.vue'
import { usePhotosStore } from '@/stores/photos'
import { useImagePicker } from '@/composables/useImagePicker'
import { errorMessage } from '@/services/errors'
import { ACCEPTED_IMAGE_TYPES } from '@/utils/image'
import { LIMITS } from '@/utils/validation'
import { plural } from '@/utils/text'
import { uid } from '@/utils/ids'

// Every photo goes to "Mis fotos"; from there it can be added to other albums.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
})

const emit = defineEmits(['close'])

// STORES
const photos = usePhotosStore()

// DATA
const items = ref([])
const input = ref(null)
const uploading = ref(false)
const error = ref('')
const dragging = ref(false)
const together = ref(false)
const coOwners = ref([])
const { processing, read } = useImagePicker()

// COMPUTED
const busy = computed(() => uploading.value || processing.value)

// METHODS
const add = async (files) => {
  const images = await read([...files].filter((f) => f.type.startsWith('image/')))
  items.value = [...items.value, ...images.map((image) => ({ ...image, caption: '', key: uid('up') }))]
}

const onPick = async (event) => {
  await add(event.target.files)
  event.target.value = ''
}

const onDrop = async (event) => {
  dragging.value = false
  if (event.dataTransfer?.files?.length) await add(event.dataTransfer.files)
}

const upload = async () => {
  uploading.value = true
  error.value = ''
  try {
    await photos.uploadPhotos(
      items.value.map(({ dataUrl, width, height, caption }) => ({ dataUrl, width, height, caption })),
      together.value ? coOwners.value : [],
    )
    emit('close')
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    uploading.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (open) {
      items.value = []
      error.value = ''
      together.value = false
      coOwners.value = []
    }
  },
)
</script>

<template>
  <BaseModal :open="open" title="Subir fotografías" size="lg" :busy="uploading" @close="emit('close')">
    <div
      class="upload__drop"
      :class="{ 'upload__drop--active': dragging }"
      @dragover.prevent="dragging = true"
      @dragleave="dragging = false"
      @drop.prevent="onDrop"
    >
      <ImagePlus class="upload__drop-icon" aria-hidden="true" />
      <p>Arrastra aquí tus fotos o</p>
      <input ref="input" class="visually-hidden" type="file" multiple :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="onPick" />
      <button type="button" class="btn btn--soft" :disabled="busy" @click="input?.click()">
        {{ processing ? 'Preparando…' : 'Elegir fotografías' }}
      </button>
    </div>

    <ul v-if="items.length" class="upload__list" role="list">
      <li v-for="(item, index) in items" :key="item.key" class="upload__item">
        <img :src="item.dataUrl" alt="" />
        <label class="visually-hidden" :for="`caption-${item.key}`">Pie de la foto {{ index + 1 }}</label>
        <input :id="`caption-${item.key}`" v-model="item.caption" class="input upload__caption" :maxlength="LIMITS.caption" placeholder="Pie de foto (opcional)" />
        <button type="button" class="btn btn--ghost btn--icon" :aria-label="`Quitar foto ${index + 1}`" @click="items.splice(index, 1)">
          <X aria-hidden="true" />
        </button>
      </li>
    </ul>
    <section v-if="items.length" class="upload__together">
      <label class="check">
        <input v-model="together" type="checkbox" />
        <span>Subir en conjunto con amigos</span>
      </label>
      <p class="upload__hint">
        Serán dueños de las fotos igual que tú: podrán etiquetar, editar el pie y las verán en su perfil. Antes tienen que aceptar la invitación.
      </p>
      <FriendPicker v-if="together" v-model="coOwners" label="¿Con quién las compartes?" />
    </section>
    <p v-if="error" class="field__error" role="alert">{{ error }}</p>

    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="uploading" @click="emit('close')">Cancelar</button>
      <button type="button" class="btn btn--primary" :disabled="!items.length || busy || (together && !coOwners.length)" @click="upload">
        {{ uploading ? 'Subiendo…' : items.length ? `Subir ${plural(items.length, 'foto', 'fotos')}` : 'Subir' }}
      </button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.upload {
  &__drop {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: $space-2;
    padding: $space-6 $space-4;
    border: 2px dashed $color-border-strong;
    border-radius: $radius;
    color: $color-text-muted;
    text-align: center;

    &--active {
      border-color: $color-brand;
      background: $color-brand-tint;
    }
  }

  &__drop-icon {
    width: 2rem;
    height: 2rem;
  }

  &__list {
    display: grid;
    gap: $space-2;
    margin: $space-4 0 0;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: $space-3;

    img {
      flex-shrink: 0;
      width: 4rem;
      height: 4rem;
      object-fit: cover;
      border-radius: $radius-sm;
    }
  }

  &__together {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    margin-top: $space-4;
    padding-top: $space-4;
    border-top: 1px solid $color-border;
  }

  &__hint {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__caption {
    flex: 1;
    min-width: 0;
  }
}
</style>
