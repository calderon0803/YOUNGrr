<script setup>
import { computed, onMounted } from 'vue'
import { CalendarPlus, Newspaper, UserPlus } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import ActivityBlock from '@/components/feed/ActivityBlock.vue'
import { useFeedStore } from '@/stores/feed'
import { dayLabel } from '@/utils/time'

// A group's news, as the friends' news: what its members do (only of the people
// you can see: friends, or who show you their whole profile in the group), who
// joined each day and its new events. The Gallinero has its own tab.

// PROPS
const props = defineProps({
  groupId: { type: String, required: true },
})

// STORES
const feed = useFeedStore()

// DATA
const SHOWN_NAMES = 3

// COMPUTED
const state = computed(() => feed.groupFeeds[props.groupId] ?? { status: 'loading', items: [], hasMore: false })

// METHODS
const joinedLabel = (people) => {
  const rest = people.length - SHOWN_NAMES
  return rest > 0 ? `y ${rest} más se han unido al grupo` : people.length === 1 ? 'se ha unido al grupo' : 'se han unido al grupo'
}

const keyOf = (item) => (item.kind === 'person' ? `p:${item.block.person.id}:${item.block.day}` : item.kind === 'joined' ? `j:${item.day}` : `e:${item.event?.id}`)

// LIFECYCLE
onMounted(() => feed.loadGroupActivity(props.groupId))
</script>

<template>
  <AsyncState :status="state.status" :error="state.error" :empty="!state.items.length" skeleton="list" @retry="feed.loadGroupActivity(groupId)">
    <template #empty>
      <StateMessage :icon="Newspaper" title="No hay novedades en el grupo." />
    </template>

    <div class="group-activity">
      <template v-for="item in state.items" :key="keyOf(item)">
        <ActivityBlock v-if="item.kind === 'person'" :block="item.block" />
        <p v-else-if="item.kind === 'joined'" class="group-activity__line">
          <UserPlus aria-hidden="true" />
          <span>
            <template v-for="(person, i) in item.people.slice(0, SHOWN_NAMES)" :key="person.id">
              <PersonLink :person="person" /><template v-if="i < Math.min(item.people.length, SHOWN_NAMES) - 1">, </template>
            </template>
            {{ joinedLabel(item.people) }}
            <span class="group-activity__day">· {{ dayLabel(item.day) }}</span>
          </span>
        </p>
        <p v-else-if="item.event" class="group-activity__line">
          <CalendarPlus aria-hidden="true" />
          <span>
            <PersonLink :person="item.event.creator" /> ha creado el evento
            <RouterLink :to="{ name: 'event', params: { id: item.event.id } }">{{ item.event.title }}</RouterLink>
          </span>
        </p>
      </template>
    </div>

    <div v-if="state.hasMore" class="group-activity__more">
      <button type="button" class="btn btn--ghost btn--sm" :disabled="state.loadingMore" @click="feed.loadGroupActivity(groupId, { more: true })">
        {{ state.loadingMore ? 'Cargando…' : 'Ver más' }}
      </button>
    </div>
  </AsyncState>
</template>

<style lang="scss" scoped>
.group-activity {
  > * + * {
    border-top: 1px solid $color-border;
  }

  &__line {
    display: flex;
    align-items: flex-start;
    gap: $space-2;
    padding: $space-3;
    font-size: $fs-sm;

    > svg {
      flex-shrink: 0;
      width: 1rem;
      height: 1rem;
      margin-top: 0.15rem;
      color: $color-text-soft;
    }
  }

  &__day {
    color: $color-text-muted;
  }

  &__more {
    display: flex;
    justify-content: center;
    padding: $space-2;
    border-top: 1px solid $color-border;
  }
}
</style>
