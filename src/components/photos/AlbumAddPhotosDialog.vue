<script setup>
import { computed, ref, watch } from 'vue'
import { Check, Images } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import { usePhotosStore } from '@/stores/photos'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/services/errors'
import { plural } from '@/utils/text'

// Photos are uploaded to "Mis fotos"; this adds some of yours to an album.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  albumId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const photos = usePhotosStore()
const auth = useAuthStore()

// DATA
const selected = ref(new Set())
const saving = ref(false)
const error = ref('')

// COMPUTED
const mine = computed(() => photos.lists[`user:${auth.meId}`] ?? { status: 'loading', ids: [], error: null })
const inAlbum = computed(() => new Set(photos.albumDetail[props.albumId]?.ids ?? []))
const candidates = computed(() => mine.value.ids.filter((id) => !inAlbum.value.has(id)).map((id) => photos.photos[id]).filter(Boolean))

// METHODS
const toggle = (id) => {
  const next = new Set(selected.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  selected.value = next
}

const save = async () => {
  saving.value = true
  error.value = ''
  try {
    await photos.addToAlbum(props.albumId, [...selected.value])
    emit('close')
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    saving.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    selected.value = new Set()
    error.value = ''
    photos.loadUserPhotos(auth.meId)
  },
)
</script>

<template>
  <BaseModal :open="open" title="Añadir fotos al álbum" size="lg" :busy="saving" @close="emit('close')">
    <AsyncState :status="mine.status" :error="mine.error" :empty="!candidates.length" skeleton="grid" :skeleton-count="8" @retry="photos.loadUserPhotos(auth.meId)">
      <template #empty>
        <StateMessage compact :icon="Images" title="No tienes más fotos para añadir." text="Sube fotos desde Mis fotos o desde la pestaña Fotos de tu perfil." />
      </template>
      <ul class="picker" role="list" aria-label="Tus fotos">
        <li v-for="photo in candidates" :key="photo.id">
          <button
            type="button"
            class="picker__item"
            :class="{ 'picker__item--on': selected.has(photo.id) }"
            :aria-pressed="selected.has(photo.id)"
            :aria-label="photo.caption || 'Foto'"
            @click="toggle(photo.id)"
          >
            <img :src="photo.url" alt="" loading="lazy" decoding="async" />
            <span v-if="selected.has(photo.id)" class="picker__check" aria-hidden="true"><Check /></span>
          </button>
        </li>
      </ul>
    </AsyncState>
    <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="saving" @click="emit('close')">Cancelar</button>
      <button type="button" class="btn btn--primary" :disabled="saving || !selected.size" @click="save">
        {{ saving ? 'Añadiendo…' : selected.size ? `Añadir ${plural(selected.size, 'foto', 'fotos')}` : 'Añadir' }}
      </button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.picker {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: $space-2;
  margin: 0;
  padding: 0;

  &__item {
    @include reset-button;
    position: relative;
    display: block;
    width: 100%;
    aspect-ratio: 1;
    overflow: hidden;
    border: 2px solid transparent;
    border-radius: $radius-sm;
    background: $color-skeleton;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }

    &--on {
      border-color: $color-brand;
    }
  }

  &__check {
    position: absolute;
    top: $space-1;
    right: $space-1;
    display: grid;
    place-items: center;
    width: 1.5rem;
    height: 1.5rem;
    border-radius: 50%;
    background: $color-brand;
    color: $color-on-brand;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .picker {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}
</style>
