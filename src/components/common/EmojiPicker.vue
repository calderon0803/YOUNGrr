<script setup>
import { nextTick, onBeforeUnmount, ref, useId } from 'vue'
import { Smile } from 'lucide-vue-next'
import { EMOJIS } from '@/config/emojis'

// A button that opens a short list of emojis and emits the chosen one. The
// button itself uses a Lucide icon: no emojis in the interface's own chrome.

// PROPS
const props = defineProps({
  /** Where the panel opens: above the button (chat) or below it. */
  placement: { type: String, default: 'bottom' },
  disabled: { type: Boolean, default: false },
})

const emit = defineEmits(['pick'])

// DATA
const open = ref(false)
const root = ref(null)
const panel = ref(null)
const panelId = useId()

// METHODS
const onOutside = (event) => {
  if (!root.value?.contains(event.target)) close()
}

const show = async () => {
  open.value = true
  document.addEventListener('pointerdown', onOutside)
  await nextTick()
  panel.value?.querySelector('button')?.focus()
}

const close = (restoreFocus = false) => {
  if (!open.value) return
  open.value = false
  document.removeEventListener('pointerdown', onOutside)
  if (restoreFocus) root.value?.querySelector('.emoji__trigger')?.focus()
}

const toggle = () => (open.value ? close() : show())

const pick = (emoji) => {
  emit('pick', emoji)
  close()
}

// Arrow keys move through the grid (8 per row), Escape closes.
const COLUMNS = 8
const onKeydown = (event) => {
  if (event.key === 'Escape') {
    event.preventDefault()
    close(true)
    return
  }
  const buttons = [...(panel.value?.querySelectorAll('button') ?? [])]
  const index = buttons.indexOf(document.activeElement)
  const step = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: COLUMNS, ArrowUp: -COLUMNS }[event.key]
  if (index === -1 || !step) return
  event.preventDefault()
  buttons[Math.max(0, Math.min(buttons.length - 1, index + step))]?.focus()
}

// LIFECYCLE
onBeforeUnmount(() => document.removeEventListener('pointerdown', onOutside))
</script>

<template>
  <div ref="root" class="emoji">
    <button
      type="button"
      class="emoji__trigger btn btn--ghost btn--icon"
      aria-label="Añadir emoji"
      aria-haspopup="true"
      :aria-expanded="open"
      :aria-controls="panelId"
      :disabled="disabled"
      @click="toggle"
    >
      <Smile aria-hidden="true" />
    </button>
    <div v-if="open" :id="panelId" ref="panel" class="emoji__panel" :class="`emoji__panel--${props.placement}`" role="group" aria-label="Emojis" @keydown="onKeydown">
      <button v-for="item in EMOJIS" :key="item.emoji" type="button" class="emoji__item" :aria-label="item.name" :title="item.name" @click="pick(item.emoji)">
        {{ item.emoji }}
      </button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.emoji {
  position: relative;
  flex-shrink: 0;

  &__panel {
    position: absolute;
    right: 0;
    z-index: 30;
    display: grid;
    grid-template-columns: repeat(8, 2rem);
    gap: 0.15rem;
    max-height: 13rem;
    overflow-y: auto;
    padding: $space-2;
    border: 1px solid $color-border;
    border-radius: $radius;
    background: $color-surface;
    box-shadow: 0 8px 24px $color-shadow;

    &--top {
      bottom: calc(100% + #{$space-1});
    }

    &--bottom {
      top: calc(100% + #{$space-1});
    }
  }

  &__item {
    @include reset-button;
    display: grid;
    place-items: center;
    width: 2rem;
    height: 2rem;
    border-radius: $radius-sm;
    font-size: 1.25rem;
    line-height: 1;

    &:hover,
    &:focus-visible {
      background: $color-surface-hover;
    }

    &:focus-visible {
      @include focus-ring;
    }
  }
}
</style>
