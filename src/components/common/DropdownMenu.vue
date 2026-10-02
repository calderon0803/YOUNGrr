<script setup>
import { nextTick, onBeforeUnmount, ref, useId } from 'vue'
import { Ellipsis } from 'lucide-vue-next'
import NavBadge from '@/components/layout/NavBadge.vue'

// PROPS
defineProps({
  /** [{ key, label, danger?, count?, badge? }]: count shows a badge, badge describes it. */
  items: { type: Array, required: true },
  label: { type: String, default: 'Opciones' },
  onDark: { type: Boolean, default: false },
})

const emit = defineEmits(['select'])

// DATA
const open = ref(false)
const root = ref(null)
const menu = ref(null)
const menuId = useId()

// METHODS
const onOutside = (event) => {
  if (root.value && !root.value.contains(event.target)) close()
}

const focusItem = (index) => {
  const items = menu.value?.querySelectorAll('[role="menuitem"]') ?? []
  if (!items.length) return
  items[(index + items.length) % items.length].focus()
}

const show = async () => {
  open.value = true
  document.addEventListener('pointerdown', onOutside)
  await nextTick()
  focusItem(0)
}

const close = ({ restoreFocus = false } = {}) => {
  open.value = false
  document.removeEventListener('pointerdown', onOutside)
  if (restoreFocus) root.value?.querySelector('.dropdown__trigger')?.focus()
}

const toggle = () => (open.value ? close() : show())

const onKeydown = (event) => {
  const items = [...(menu.value?.querySelectorAll('[role="menuitem"]') ?? [])]
  const index = items.indexOf(document.activeElement)
  if (event.key === 'ArrowDown') {
    event.preventDefault()
    focusItem(index + 1)
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    focusItem(index - 1)
  } else if (event.key === 'Escape') {
    event.stopPropagation()
    close({ restoreFocus: true })
  } else if (event.key === 'Tab') {
    close()
  }
}

const choose = (key) => {
  close({ restoreFocus: true })
  emit('select', key)
}

// LIFECYCLE
onBeforeUnmount(() => document.removeEventListener('pointerdown', onOutside))
</script>

<template>
  <div ref="root" class="dropdown">
    <button
      type="button"
      class="dropdown__trigger btn btn--ghost btn--icon"
      :class="{ 'dropdown__trigger--on-dark': onDark }"
      :aria-label="label"
      aria-haspopup="menu"
      :aria-expanded="open"
      :aria-controls="menuId"
      @click="toggle"
    >
      <Ellipsis aria-hidden="true" />
      <NavBadge class="dropdown__badge" :count="items.reduce((n, item) => n + (item.count ?? 0), 0)" label="pendientes en este menú" />
    </button>
    <Transition name="dropdown">
      <ul v-if="open" :id="menuId" ref="menu" class="dropdown__menu" role="menu" @keydown="onKeydown">
        <li v-for="item in items" :key="item.key" role="none">
          <button
            type="button"
            role="menuitem"
            class="dropdown__item"
            :class="{ 'dropdown__item--danger': item.danger }"
            @click="choose(item.key)"
          >
            {{ item.label }}
            <NavBadge :count="item.count ?? 0" :label="item.badge ?? 'pendientes'" />
          </button>
        </li>
      </ul>
    </Transition>
  </div>
</template>

<style lang="scss" scoped>
.dropdown {
  position: relative;

  &__badge {
    position: absolute;
    top: -0.2rem;
    right: -0.2rem;
  }

  &__trigger {
    position: relative;
  }

  &__trigger--on-dark {
    color: $color-viewer-text;
  }

  &__menu {
    position: absolute;
    top: calc(100% + #{$space-1});
    right: 0;
    z-index: $z-dropdown;
    min-width: 11rem;
    margin: 0;
    padding: $space-1;
    list-style: none;
    // Its own text color: in the header it would inherit the light text of the bar.
    color: $color-text;
    background: $color-surface;
    border: 1px solid $color-border-strong;
    border-radius: $radius;
    box-shadow: 0 6px 18px $color-shadow;
  }

  &__item {
    @include reset-button;
    display: block;
    width: 100%;
    padding: $space-2 $space-3;
    border-radius: $radius-sm;
    font-size: $fs-base;
    text-align: left;

    .badge {
      margin-left: $space-2;
    }

    &:hover,
    &:focus-visible {
      background: $color-surface-hover;
      outline: none;
    }

    &--danger {
      color: $color-danger;
    }
  }
}

.dropdown-enter-active,
.dropdown-leave-active {
  transition:
    opacity $duration-fast,
    transform $duration-fast $ease-out;
}

.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: translateY(-0.25rem);
}
</style>
