<script setup>
import { computed, onBeforeUnmount, ref, useId, watch } from 'vue'
import { Check, MapPin } from 'lucide-vue-next'
import { useUserStore } from '@/stores/user'
import { errorMessage } from '@/services/errors'
import { debounce } from '@/utils/debounce'
import { GEOCODER } from '@/config/app'

// Town/city combobox: the user types, picks a suggestion and we keep its
// coordinates. Free text without picking a suggestion is not a valid location.

// PROPS
const props = defineProps({
  /** { name, lat, lng } or null */
  modelValue: { type: Object, default: null },
  label: { type: String, default: 'Ciudad o pueblo' },
  hint: { type: String, default: '' },
  error: { type: String, default: '' },
})

const emit = defineEmits(['update:modelValue'])

// STORES
const user = useUserStore()

// DATA
const inputId = useId()
const listId = useId()
const query = ref(props.modelValue?.name ?? '')
const suggestions = ref([])
const status = ref('idle')
const searchError = ref('')
const open = ref(false)
const activeIndex = ref(-1)
let controller = null

// COMPUTED
const selected = computed(() => !!props.modelValue && props.modelValue.name === query.value)
const describedBy = computed(() => [props.hint && `${inputId}-hint`, `${inputId}-error`].filter(Boolean).join(' '))

// METHODS
const search = debounce(async (q) => {
  controller?.abort()
  controller = new AbortController()
  status.value = 'loading'
  searchError.value = ''
  try {
    suggestions.value = await user.searchPlaces(q, { signal: controller.signal })
    status.value = 'success'
    activeIndex.value = suggestions.value.length ? 0 : -1
  } catch (e) {
    if (e?.name === 'AbortError') return
    status.value = 'error'
    searchError.value = errorMessage(e)
  }
}, GEOCODER.debounceMs)

const onInput = () => {
  if (props.modelValue) emit('update:modelValue', null)
  open.value = query.value.trim().length >= 2
  if (open.value) search(query.value)
  else suggestions.value = []
}

const choose = (place) => {
  query.value = place.name
  emit('update:modelValue', { name: place.name, lat: place.lat, lng: place.lng })
  open.value = false
}

const onKeydown = (event) => {
  if (!open.value || !suggestions.value.length) return
  if (event.key === 'ArrowDown') {
    event.preventDefault()
    activeIndex.value = (activeIndex.value + 1) % suggestions.value.length
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    activeIndex.value = (activeIndex.value - 1 + suggestions.value.length) % suggestions.value.length
  } else if (event.key === 'Enter' && activeIndex.value >= 0) {
    event.preventDefault()
    choose(suggestions.value[activeIndex.value])
  } else if (event.key === 'Escape') {
    event.stopPropagation()
    open.value = false
  }
}

// Delay so a click on a suggestion lands before the list closes.
const onBlur = () => setTimeout(() => (open.value = false), 150)

// LIFECYCLE
onBeforeUnmount(() => {
  search.cancel()
  controller?.abort()
})

// WATCHERS
watch(
  () => props.modelValue,
  (value) => {
    if (value && value.name !== query.value) query.value = value.name
  },
)
</script>

<template>
  <div class="field city-picker">
    <label class="field__label" :for="inputId">{{ label }}</label>
    <div class="city-picker__control">
      <MapPin class="city-picker__icon" aria-hidden="true" />
      <input
        :id="inputId"
        v-model="query"
        class="input city-picker__input"
        role="combobox"
        autocomplete="off"
        aria-autocomplete="list"
        :aria-expanded="open"
        :aria-controls="listId"
        :aria-activedescendant="open && activeIndex >= 0 ? `${listId}-${activeIndex}` : undefined"
        :aria-invalid="!!error || undefined"
        :aria-describedby="describedBy"
        placeholder="Escribe y elige de la lista"
        @input="onInput"
        @keydown="onKeydown"
        @focus="open = query.trim().length >= 2 && !selected"
        @blur="onBlur"
      />
      <Check v-if="selected" class="city-picker__ok" aria-hidden="true" />
      <div v-if="open" class="city-picker__popup">
        <p v-if="status === 'loading' && !suggestions.length" class="city-picker__note">Buscando…</p>
        <p v-else-if="status === 'error'" class="city-picker__note city-picker__note--error">{{ searchError }}</p>
        <p v-else-if="status === 'success' && !suggestions.length" class="city-picker__note">No encontramos ese lugar. Prueba con otro nombre.</p>
        <ul :id="listId" class="city-picker__list" role="listbox" :aria-label="label">
          <li
            v-for="(place, index) in suggestions"
            :id="`${listId}-${index}`"
            :key="place.id"
            role="option"
            class="city-picker__option"
            :class="{ 'city-picker__option--active': index === activeIndex }"
            :aria-selected="index === activeIndex"
            @mousedown.prevent="choose(place)"
            @mouseenter="activeIndex = index"
          >
            <span class="city-picker__name">{{ place.name }}</span>
            <span v-if="place.detail" class="city-picker__detail">{{ place.detail }}</span>
          </li>
        </ul>
        <p class="city-picker__credit">Datos de © OpenStreetMap</p>
      </div>
    </div>

    <p v-if="hint" :id="`${inputId}-hint`" class="field__hint">{{ hint }}</p>
    <p :id="`${inputId}-error`" class="field__error">{{ error }}</p>
  </div>
</template>

<style lang="scss" scoped>
.city-picker {
  &__control {
    position: relative;
  }

  &__icon {
    position: absolute;
    top: 50%;
    left: $space-3;
    width: 1rem;
    height: 1rem;
    color: $color-text-soft;
    transform: translateY(-50%);
  }

  &__input {
    padding-right: 2.25rem;
    padding-left: 2.25rem;
  }

  &__ok {
    position: absolute;
    top: 50%;
    right: $space-3;
    width: 1.1rem;
    height: 1.1rem;
    color: $color-success;
    transform: translateY(-50%);
  }

  &__popup {
    position: absolute;
    top: calc(100% + #{$space-1});
    right: 0;
    left: 0;
    z-index: $z-dropdown;
    padding: $space-1;
    background: $color-surface;
    border: 1px solid $color-border-strong;
    border-radius: $radius;
    box-shadow: 0 6px 18px $color-shadow;
  }

  &__list {
    max-height: 15rem;
    margin: 0;
    padding: 0;
    overflow-y: auto;
    list-style: none;
  }

  &__option {
    display: flex;
    flex-direction: column;
    padding: $space-2 $space-3;
    border-radius: $radius-sm;
    cursor: pointer;

    &--active {
      background: $color-brand-tint;
    }
  }

  &__name {
    font-weight: 600;
  }

  &__detail {
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__note {
    padding: $space-2 $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;

    &--error {
      color: $color-danger;
    }
  }

  &__credit {
    padding: $space-1 $space-3 0;
    font-size: 0.6875rem;
    color: $color-text-soft;
    text-align: right;
  }
}
</style>
