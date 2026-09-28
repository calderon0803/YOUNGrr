<script setup>
import { onBeforeUnmount, ref, toRef, useId, watch } from 'vue'
import { X } from 'lucide-vue-next'
import { useFocusTrap } from '@/composables/useFocusTrap'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  title: { type: String, required: true },
  size: { type: String, default: 'md', validator: (v) => ['sm', 'md', 'lg'].includes(v) },
  /** Prevents closing while a request is in flight. */
  busy: { type: Boolean, default: false },
})

const emit = defineEmits(['close'])

// DATA
const panel = ref(null)
const titleId = useId()

// METHODS
const close = () => {
  if (!props.busy) emit('close')
}

useFocusTrap(panel, toRef(props, 'open'), { onEscape: close })

// LIFECYCLE
onBeforeUnmount(() => document.body.classList.remove('has-modal'))

// WATCHERS
watch(
  () => props.open,
  (open) => document.body.classList.toggle('has-modal', open),
  { immediate: true },
)
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="open" class="modal" @mousedown.self="close">
        <section
          ref="panel"
          class="modal__panel"
          :class="`modal__panel--${size}`"
          role="dialog"
          aria-modal="true"
          :aria-labelledby="titleId"
          tabindex="-1"
        >
          <header class="modal__header">
            <h2 :id="titleId" class="modal__title">{{ title }}</h2>
            <button type="button" class="btn btn--ghost btn--icon" aria-label="Cerrar" :disabled="busy" @click="close">
              <X aria-hidden="true" />
            </button>
          </header>
          <div class="modal__body">
            <slot />
          </div>
          <footer v-if="$slots.footer" class="modal__footer">
            <slot name="footer" />
          </footer>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>

<style lang="scss" scoped>
.modal {
  position: fixed;
  inset: 0;
  z-index: $z-modal;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  background: $color-overlay;

  &__panel {
    display: flex;
    flex-direction: column;
    width: 100%;
    max-height: 92dvh;
    background: $color-surface;
    border-radius: $radius-lg $radius-lg 0 0;
    outline: none;
    padding-bottom: env(safe-area-inset-bottom);
  }

  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: $space-3;
    padding: $space-3 $space-3 $space-3 $space-4;
    border-bottom: 1px solid $color-border;
  }

  &__title {
    font-size: $fs-md;
    font-weight: 700;
  }

  &__body {
    overflow-y: auto;
    padding: $space-4;
  }

  &__footer {
    display: flex;
    justify-content: flex-end;
    gap: $space-2;
    padding: $space-3 $space-4;
    border-top: 1px solid $color-border;
  }
}

.modal-enter-active,
.modal-leave-active {
  transition: opacity $duration $ease-out;

  .modal__panel {
    transition: transform $duration $ease-out;
  }
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;

  .modal__panel {
    transform: translateY(1.5rem);
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .modal {
    align-items: center;
    padding: $space-6;

    &__panel {
      max-height: 85dvh;
      border-radius: $radius-lg;
      padding-bottom: 0;

      &--sm {
        max-width: 26rem;
      }

      &--md {
        max-width: 34rem;
      }

      &--lg {
        max-width: 46rem;
      }
    }
  }
}
</style>
