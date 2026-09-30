<script setup>
import { computed, onMounted, reactive } from 'vue'
import { ChevronDown, ChevronRight } from 'lucide-vue-next'
import { useGroupsStore } from '@/stores/groups'
import { groupKindLabel } from '@/utils/groups'
import { plural } from '@/utils/text'

// The place groups as a tree: communities, their provinces and the towns that
// already have a group. Each level loads when it is opened.

// PROPS
const props = defineProps({
  /** null for the communities. */
  parentId: { type: String, default: null },
})

// STORES
const groups = useGroupsStore()

// DATA
const opened = reactive({})

// COMPUTED
const state = computed(() => groups.places[props.parentId ?? ''] ?? { status: 'loading', ids: [] })
const items = computed(() => state.value.ids.map((id) => groups.groups[id]).filter(Boolean))

// METHODS
const toggle = (group) => {
  opened[group.id] = !opened[group.id]
}

// LIFECYCLE
onMounted(() => {
  if (!groups.places[props.parentId ?? '']) groups.loadPlaces(props.parentId)
})
</script>

<template>
  <p v-if="state.status === 'loading' && !items.length" class="place-tree__muted">Cargando…</p>
  <p v-else-if="state.status === 'error'" class="place-tree__muted">{{ state.error }}</p>
  <p v-else-if="!items.length" class="place-tree__muted">Todavía no hay grupos de pueblos o ciudades aquí.</p>
  <ul v-else class="place-tree" :class="{ 'place-tree--nested': parentId }" role="list">
    <li v-for="group in items" :key="group.id" class="place-tree__item">
      <div class="place-tree__row">
        <button
          v-if="group.placeLevel !== 'municipality'"
          type="button"
          class="place-tree__toggle"
          :aria-expanded="!!opened[group.id]"
          :aria-label="`${opened[group.id] ? 'Ocultar' : 'Ver'} los grupos de ${group.name}`"
          @click="toggle(group)"
        >
          <component :is="opened[group.id] ? ChevronDown : ChevronRight" aria-hidden="true" />
        </button>
        <span v-else class="place-tree__spacer" aria-hidden="true" />
        <RouterLink class="place-tree__name" :to="{ name: 'group', params: { id: group.id } }">{{ group.name }}</RouterLink>
        <span class="place-tree__meta">{{ groupKindLabel(group) }} · {{ plural(group.memberCount, 'persona', 'personas') }}</span>
        <span v-if="group.myRole" class="place-tree__in">Estás dentro</span>
        <button v-else type="button" class="btn btn--secondary btn--sm place-tree__join" @click="groups.requestToJoin(group.id)">Unirme</button>
      </div>
      <PlaceTree v-if="opened[group.id]" :parent-id="group.id" />
    </li>
  </ul>
</template>

<style lang="scss" scoped>
.place-tree {
  margin: 0;
  padding: 0;

  &--nested {
    padding-left: $space-5;
  }

  &__row {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: $space-1 $space-2;
    padding: $space-1 0;
  }

  &__toggle {
    @include reset-button;
    display: grid;
    place-items: center;
    width: 1.5rem;
    height: 1.5rem;
    border-radius: $radius-sm;
    color: $color-text-muted;

    svg {
      width: 1rem;
      height: 1rem;
    }

    &:hover {
      background: $color-surface-hover;
    }
  }

  &__spacer {
    width: 1.5rem;
  }

  &__name {
    font-weight: 700;
  }

  &__meta,
  &__in {
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__in {
    color: $color-success;
    font-weight: 600;
  }

  &__join {
    margin-left: auto;
  }

  &__muted {
    padding: $space-1 0 $space-1 $space-5;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
