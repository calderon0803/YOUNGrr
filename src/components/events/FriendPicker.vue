<script setup>
import { computed, onMounted, ref, useId } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useAuthStore } from '@/stores/auth'
import { useFriendsStore } from '@/stores/friends'
import { fullName, matches } from '@/utils/text'

// Multi-select list of friends: event invitations, photo co-owners...

// PROPS
const props = defineProps({
  modelValue: { type: Array, required: true },
  /** Friends already invited: shown disabled. */
  excluded: { type: Array, default: () => [] },
  label: { type: String, default: 'Invitar a amigos' },
  excludedLabel: { type: String, default: 'Ya invitado' },
})

const emit = defineEmits(['update:modelValue'])

// STORES
const auth = useAuthStore()
const friends = useFriendsStore()

// DATA
const query = ref('')
const filterId = useId()

// COMPUTED
const state = computed(() => friends.lists[auth.meId] ?? { status: 'loading', items: [] })
const options = computed(() => state.value.items.filter((p) => !query.value.trim() || matches(fullName(p), query.value)))

// METHODS
const toggle = (id) => {
  const next = props.modelValue.includes(id) ? props.modelValue.filter((x) => x !== id) : [...props.modelValue, id]
  emit('update:modelValue', next)
}

// LIFECYCLE
onMounted(() => friends.loadFriends(auth.meId))
</script>

<template>
  <fieldset class="picker">
    <legend class="field__label">{{ label }}</legend>
    <label class="visually-hidden" :for="filterId">Filtrar amigos</label>
    <input :id="filterId" v-model="query" class="input picker__filter" placeholder="Buscar entre tus amigos" autocomplete="off" />
    <p v-if="state.status === 'loading'" class="picker__hint">Cargando amigos…</p>
    <p v-else-if="!state.items.length" class="picker__hint">Todavía no tienes amigos a los que invitar.</p>
    <ul v-else class="picker__list" role="list">
      <li v-for="person in options" :key="person.id">
        <label class="picker__option" :class="{ 'picker__option--disabled': excluded.includes(person.id) }">
          <input
            type="checkbox"
            :checked="modelValue.includes(person.id) || excluded.includes(person.id)"
            :disabled="excluded.includes(person.id)"
            @change="toggle(person.id)"
          />
          <UserAvatar :person="person" size="xs" />
          <span>{{ fullName(person) }}</span>
          <span v-if="excluded.includes(person.id)" class="picker__already">{{ excludedLabel }}</span>
        </label>
      </li>
    </ul>
    <p class="picker__hint" aria-live="polite">{{ modelValue.length ? `${modelValue.length} seleccionados` : '' }}</p>
  </fieldset>
</template>

<style lang="scss" scoped>
.picker {
  display: flex;
  flex-direction: column;
  gap: $space-2;
  margin: 0;
  padding: 0;
  border: 0;

  &__list {
    max-height: 14rem;
    margin: 0;
    overflow-y: auto;
    border: 1px solid $color-border;
    border-radius: $radius;
  }

  &__option {
    display: flex;
    align-items: center;
    gap: $space-2;
    padding: $space-2 $space-3;
    cursor: pointer;

    input {
      width: 1.05rem;
      height: 1.05rem;
      accent-color: $color-brand;
    }

    &:hover {
      background: $color-surface-hover;
    }

    &--disabled {
      cursor: default;
      color: $color-text-muted;
    }
  }

  &__already {
    margin-left: auto;
    font-size: $fs-xs;
  }

  &__hint {
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
