<script setup>
import { X } from 'lucide-vue-next'
import { useToast } from '@/composables/useToast'

// DATA
const { toasts, dismiss } = useToast()

// METHODS
const runAction = (toast) => {
  toast.action?.run()
  dismiss(toast.id)
}
</script>

<template>
  <div class="toasts" role="status" aria-live="polite" aria-atomic="false">
    <TransitionGroup name="toast">
      <div v-for="toast in toasts" :key="toast.id" class="toast" :class="`toast--${toast.tone}`">
        <span class="toast__message">{{ toast.message }}</span>
        <button v-if="toast.action" type="button" class="toast__action" @click="runAction(toast)">
          {{ toast.action.label }}
        </button>
        <button type="button" class="toast__close" aria-label="Cerrar aviso" @click="dismiss(toast.id)">
          <X aria-hidden="true" />
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>

<style lang="scss" scoped>
.toasts {
  position: fixed;
  right: 0;
  bottom: calc(#{$bottom-nav-height} + env(safe-area-inset-bottom) + #{$space-3});
  left: 0;
  z-index: $z-toast;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: $space-2;
  padding: 0 $space-3;
  pointer-events: none;
}

.toast {
  display: flex;
  align-items: center;
  gap: $space-3;
  max-width: 26rem;
  padding: $space-2 $space-2 $space-2 $space-4;
  background: $color-toast-bg;
  color: $color-toast-text;
  border-radius: $radius;
  box-shadow: 0 4px 14px $color-shadow;
  font-size: $fs-base;
  pointer-events: auto;

  &--success {
    border-left: 3px solid $color-success;
  }

  &--error {
    border-left: 3px solid $color-danger;
  }

  &__message {
    flex: 1;
  }

  &__action {
    @include reset-button;
    font-weight: 700;
    color: $color-grr-logo;
  }

  &__close {
    @include reset-button;
    display: grid;
    place-items: center;
    width: 1.75rem;
    height: 1.75rem;
    opacity: 0.7;

    svg {
      width: 1rem;
      height: 1rem;
    }

    &:hover {
      opacity: 1;
    }
  }
}

.toast-enter-active,
.toast-leave-active {
  transition:
    opacity $duration $ease-out,
    transform $duration $ease-out;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(0.5rem);
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .toasts {
    right: $space-6;
    bottom: $space-6;
    left: auto;
    align-items: flex-end;
  }
}
</style>
