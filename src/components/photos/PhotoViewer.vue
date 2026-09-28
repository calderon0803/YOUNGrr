<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ChevronLeft, ChevronRight, CircleAlert, Tag, X } from 'lucide-vue-next'
import PhotoTagLayer from '@/components/photos/PhotoTagLayer.vue'
import PhotoDetails from '@/components/photos/PhotoDetails.vue'
import TagPicker from '@/components/photos/TagPicker.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import { usePhotosStore } from '@/stores/photos'
import { useFocusTrap } from '@/composables/useFocusTrap'

// STORES
const photos = usePhotosStore()
const route = useRoute()
const router = useRouter()

// DATA
const dialog = ref(null)
const frame = ref(null)
const tagging = ref(false)
const showTags = ref(false)
const highlightId = ref(null)
const draft = ref(null)
const imageFailed = ref(false)
let touchStart = null

// COMPUTED
const open = computed(() => photos.viewer.open)
const photo = computed(() => photos.currentPhoto)
const hasMany = computed(() => photos.viewer.ids.length > 1)
const counter = computed(() => `${photos.viewer.index + 1} de ${photos.viewer.ids.length}`)
const frameStyle = computed(() => (photo.value ? { aspectRatio: `${photo.value.width} / ${photo.value.height}`, '--ratio': photo.value.width / photo.value.height } : {}))
const pickerStyle = computed(() => {
  if (!draft.value) return {}
  // Keep the picker inside the frame.
  return {
    left: `${Math.min(Math.max(draft.value.x * 100, 20), 80)}%`,
    top: `${Math.min(draft.value.y * 100 + 10, 60)}%`,
  }
})

// METHODS
const close = () => {
  photos.closeViewer()
  if (route.query.photo) {
    const { photo: _removed, ...query } = route.query
    router.replace({ query })
  }
}

const step = (delta) => {
  draft.value = null
  photos.step(delta)
}

const onKeydown = (event) => {
  if (draft.value || event.target.closest?.('input, textarea')) return
  if (event.key === 'ArrowLeft') step(-1)
  else if (event.key === 'ArrowRight') step(1)
}

const onFrameClick = (event) => {
  if (!tagging.value) {
    // Touch devices have no hover: tapping the photo shows or hides the tags.
    showTags.value = !showTags.value
    return
  }
  const rect = frame.value.getBoundingClientRect()
  draft.value = {
    x: Math.min(Math.max((event.clientX - rect.left) / rect.width, 0.05), 0.95),
    y: Math.min(Math.max((event.clientY - rect.top) / rect.height, 0.05), 0.95),
  }
}

const pickTag = async (userId) => {
  const { x, y } = draft.value
  draft.value = null
  if (await photos.addTag(photo.value.id, userId, x, y)) tagging.value = false
}

const onTouchStart = (event) => {
  touchStart = { x: event.touches[0].clientX, y: event.touches[0].clientY }
}

const onTouchEnd = (event) => {
  if (!touchStart || tagging.value) return
  const dx = event.changedTouches[0].clientX - touchStart.x
  const dy = event.changedTouches[0].clientY - touchStart.y
  if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) step(dx < 0 ? 1 : -1)
  touchStart = null
}

// LIFECYCLE
useFocusTrap(dialog, open, { onEscape: () => (draft.value ? (draft.value = null) : close()) })

onMounted(() => {
  document.body.classList.add('has-modal')
  document.addEventListener('keydown', onKeydown)
})

onBeforeUnmount(() => {
  document.body.classList.remove('has-modal')
  document.removeEventListener('keydown', onKeydown)
})

// WATCHERS
watch(
  () => photo.value?.id,
  (id) => {
    tagging.value = false
    draft.value = null
    imageFailed.value = false
    if (id && route.query.photo && route.query.photo !== id) router.replace({ query: { ...route.query, photo: id } })
  },
)
</script>

<template>
  <Teleport to="body">
    <div ref="dialog" class="viewer" role="dialog" aria-modal="true" aria-label="Visor de fotografías" tabindex="-1">
      <div class="viewer__dialog">
        <div class="viewer__stage" @touchstart.passive="onTouchStart" @touchend="onTouchEnd">
          <div class="viewer__topbar">
            <span v-if="hasMany" class="viewer__counter" aria-live="polite">{{ counter }}</span>
            <button v-if="photo?.tags.length" type="button" class="viewer__tool" :aria-pressed="showTags" @click="showTags = !showTags">
              <Tag aria-hidden="true" />
              <span>{{ showTags ? 'Ocultar etiquetas' : 'Ver etiquetas' }}</span>
            </button>
            <button type="button" class="viewer__close" aria-label="Cerrar visor" @click="close">
              <X aria-hidden="true" />
            </button>
          </div>

          <button v-if="hasMany" type="button" class="viewer__nav viewer__nav--prev" aria-label="Foto anterior" @click="step(-1)">
            <ChevronLeft aria-hidden="true" />
          </button>

          <figure v-if="photo" class="viewer__figure">
            <Transition name="photo" mode="out-in">
              <div
                :key="photo.id"
                ref="frame"
                class="viewer__frame"
                :class="{ 'viewer__frame--tagging': tagging }"
                :style="frameStyle"
                @click="onFrameClick"
              >
                <img v-if="!imageFailed" class="viewer__image" :src="photo.url" :alt="photo.caption || `Fotografía de ${photo.owner.firstName}`" @error="imageFailed = true" />
                <p v-else class="viewer__image-error">No se ha podido cargar la imagen.</p>
                <PhotoTagLayer :tags="photo.tags" :visible="showTags || tagging" :highlight-id="highlightId" :draft="draft" />
                <div v-if="draft" class="viewer__picker" :style="pickerStyle" @click.stop>
                  <TagPicker :excluded="photo.tags.map((t) => t.userId)" @pick="pickTag" @cancel="draft = null" />
                </div>
              </div>
            </Transition>
          </figure>
          <div v-else-if="photos.viewer.detailStatus === 'error'" class="viewer__state">
            <StateMessage tone="error" :icon="CircleAlert" title="No se ha podido abrir la foto" :text="photos.viewer.detailError ?? ''">
              <button type="button" class="btn btn--secondary" @click="close">Cerrar</button>
            </StateMessage>
          </div>
          <div v-else class="viewer__state" aria-busy="true">
            <span class="viewer__spinner" />
            <span class="visually-hidden">Cargando fotografía…</span>
          </div>

          <button v-if="hasMany" type="button" class="viewer__nav viewer__nav--next" aria-label="Foto siguiente" @click="step(1)">
            <ChevronRight aria-hidden="true" />
          </button>
        </div>

        <aside v-if="photo" class="viewer__side" aria-label="Información de la fotografía">
          <PhotoDetails
            :photo="photo"
            :tagging="tagging"
            :comments-loading="photos.viewer.detailStatus === 'loading'"
            @toggle-tagging="((tagging = !tagging), (draft = null))"
            @highlight="highlightId = $event"
            @close="close"
          />
        </aside>
      </div>
    </div>
  </Teleport>
</template>

<style lang="scss" scoped>
.viewer {
  position: fixed;
  inset: 0;
  z-index: $z-viewer;
  overflow-y: auto;
  background: $color-viewer-solid;
  color: $color-viewer-text;
  outline: none;
  animation: viewer-in $duration $ease-out;

  &__dialog {
    display: flex;
    flex-direction: column;
    min-height: 100%;
  }

  &__stage {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 62dvh;
    padding: calc(3.25rem + env(safe-area-inset-top)) 0 $space-3;
  }

  &__topbar {
    position: absolute;
    top: env(safe-area-inset-top);
    right: 0;
    left: 0;
    z-index: 2;
    display: flex;
    align-items: center;
    gap: $space-2;
    height: 3.25rem;
    padding: 0 $space-2 0 $space-4;
  }

  &__counter {
    font-size: $fs-sm;
    font-weight: 600;
  }

  &__tool {
    @include reset-button;
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    margin-left: auto;
    padding: $space-1 $space-2;
    border-radius: $radius;
    font-size: $fs-sm;
    font-weight: 600;

    svg {
      width: 1rem;
      height: 1rem;
    }

    &[aria-pressed='true'] {
      color: $color-grr-logo;
    }
  }

  &__close {
    @include reset-button;
    display: grid;
    place-items: center;
    width: 2.5rem;
    height: 2.5rem;
    margin-left: auto;
    border-radius: $radius;

    svg {
      width: 1.5rem;
      height: 1.5rem;
    }

    &:hover {
      background: $color-overlay;
    }
  }

  &__tool + &__close {
    margin-left: 0;
  }

  &__nav {
    @include reset-button;
    position: absolute;
    top: 50%;
    z-index: 2;
    display: grid;
    place-items: center;
    width: 2.75rem;
    height: 2.75rem;
    border-radius: $radius;
    background: $color-overlay;
    transform: translateY(-50%);

    svg {
      width: 1.6rem;
      height: 1.6rem;
    }

    &:hover {
      background: $color-toast-bg;
      color: $color-toast-text;
    }

    &--prev {
      left: $space-2;
    }

    &--next {
      right: $space-2;
    }
  }

  &__figure {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
  }

  &__frame {
    position: relative;
    width: min(100%, calc((62dvh - 4rem) * var(--ratio, 1.5)));
    user-select: none;

    &--tagging {
      cursor: crosshair;
    }
  }

  &__image {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }

  &__image-error {
    display: grid;
    place-items: center;
    width: 100%;
    height: 100%;
    min-height: 12rem;
    color: $color-text-soft;
  }

  &__picker {
    position: absolute;
    z-index: 3;
    transform: translateX(-50%);
  }

  &__state {
    display: grid;
    place-items: center;
    width: 100%;
    min-height: 16rem;
  }

  &__spinner {
    width: 2rem;
    height: 2rem;
    border: 3px solid $color-overlay;
    border-top-color: $color-viewer-text;
    border-radius: 50%;
    animation: viewer-spin 0.8s linear infinite;
  }

  &__side {
    flex: 1;
    background: $color-surface;
    color: $color-text;
    padding-bottom: env(safe-area-inset-bottom);
  }
}

.photo-enter-active,
.photo-leave-active {
  transition: opacity 140ms;
}

.photo-enter-from,
.photo-leave-to {
  opacity: 0;
}

@keyframes viewer-in {
  from {
    opacity: 0;
  }
}

@keyframes viewer-zoom {
  from {
    transform: scale(0.97);
  }
}

@keyframes viewer-spin {
  to {
    transform: rotate(360deg);
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .viewer {
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    padding: $space-6;
    background: $color-overlay;

    &__dialog {
      display: grid;
      grid-template-columns: minmax(0, 1fr) 21rem;
      width: 100%;
      max-width: 82rem;
      height: 100%;
      min-height: 0;
      max-height: 56rem;
      overflow: hidden;
      border-radius: $radius-lg;
      background: $color-viewer-bg;
      animation: viewer-zoom $duration $ease-out;
    }

    &__stage {
      min-height: 0;
      padding: 3.25rem 4.25rem $space-6;
    }

    &__topbar {
      top: 0;
    }

    &__frame {
      width: min(100%, calc((min(100dvh, 59rem) - 12.5rem) * var(--ratio, 1.5)));

      &:hover :deep(.tag-layer__tag) {
        opacity: 1;
      }
    }

    &__nav {
      &--prev {
        left: $space-3;
      }

      &--next {
        right: $space-3;
      }
    }

    &__side {
      overflow-y: auto;
      border-left: 1px solid $color-border;
      padding-bottom: 0;
    }
  }
}
</style>
