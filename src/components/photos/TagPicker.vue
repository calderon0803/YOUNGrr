<script setup>
import { computed, onMounted, ref } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useAuthStore } from '@/stores/auth'
import { useFriendsStore } from '@/stores/friends'
import { fullName, matches } from '@/utils/text'

// Picks who to tag at the chosen point: yourself or one of your friends.

// PROPS
const props = defineProps({
  /** Ids already tagged in this photo. */
  excluded: { type: Array, default: () => [] },
})

const emit = defineEmits(['pick', 'cancel'])

// STORES
const auth = useAuthStore()
const friends = useFriendsStore()

// DATA
const query = ref('')

// COMPUTED
const options = computed(() => {
  const mine = friends.lists[auth.meId]?.items ?? []
  return [{ ...auth.me, isSelf: true }, ...mine]
    .filter((p) => !props.excluded.includes(p.id))
    .filter((p) => !query.value.trim() || matches(fullName(p), query.value))
    .slice(0, 8)
})

// LIFECYCLE
onMounted(() => {
  if (!friends.lists[auth.meId]?.items.length) friends.loadFriends(auth.meId)
})
</script>

<template>
  <div class="tag-picker" role="dialog" aria-label="Etiquetar a alguien" @keydown.esc.stop="emit('cancel')">
    <label class="visually-hidden" for="tag-search">Buscar amigo</label>
    <input id="tag-search" v-model="query" class="input tag-picker__search" placeholder="¿Quién es?" autocomplete="off" autofocus />
    <ul class="tag-picker__list" role="list">
      <li v-for="person in options" :key="person.id">
        <button type="button" class="tag-picker__option" @click="emit('pick', person.id)">
          <UserAvatar :person="person" size="xs" />
          {{ person.isSelf ? 'Yo' : fullName(person) }}
        </button>
      </li>
      <li v-if="!options.length" class="tag-picker__empty">No hay amigos con ese nombre.</li>
    </ul>
    <button type="button" class="btn btn--ghost btn--sm btn--block" @click="emit('cancel')">Cancelar</button>
  </div>
</template>

<style lang="scss" scoped>
.tag-picker {
  width: 14rem;
  padding: $space-2;
  background: $color-surface;
  border: 1px solid $color-border-strong;
  border-radius: $radius;
  box-shadow: 0 8px 24px $color-shadow;
  color: $color-text;

  &__search {
    min-height: 2rem;
    padding: $space-1 $space-2;
  }

  &__list {
    max-height: 13rem;
    margin: $space-1 0;
    overflow-y: auto;
  }

  &__option {
    @include reset-button;
    display: flex;
    align-items: center;
    gap: $space-2;
    width: 100%;
    padding: $space-1 $space-2;
    border-radius: $radius-sm;
    text-align: left;
    font-size: $fs-sm;
    font-weight: 600;

    &:hover,
    &:focus-visible {
      background: $color-surface-hover;
    }
  }

  &__empty {
    padding: $space-2;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
