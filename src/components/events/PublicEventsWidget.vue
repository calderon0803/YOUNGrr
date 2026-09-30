<script setup>
import { computed, onMounted, ref } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import EventDateBadge from '@/components/events/EventDateBadge.vue'
import { useEventsStore } from '@/stores/events'
import { plural } from '@/utils/text'
import { PUBLIC_EVENTS_SHOWN } from '@/config/app'

// "Planes públicos": upcoming public events of your friends and friends of
// friends you have not joined yet, the soonest first. A few in Inicio, one
// line each; "Ver todos" opens the whole list. Joining is done on the event.

// STORES
const events = useEventsStore()

// DATA
const showAll = ref(false)

// COMPUTED
const items = computed(() => events.publicList.ids.map((id) => events.events[id]).filter(Boolean))
const shown = computed(() => items.value.slice(0, PUBLIC_EVENTS_SHOWN))

// LIFECYCLE
onMounted(() => events.loadPublic())
</script>

<template>
  <section class="panel public-events" aria-labelledby="public-events-title">
    <h2 id="public-events-title" class="panel-title">Planes públicos</h2>
    <p v-if="!items.length && events.publicList.status !== 'loading'" class="public-events__empty">
      No hay planes públicos. <RouterLink :to="{ name: 'events' }">Crear evento</RouterLink>
    </p>
    <ul v-else class="public-events__list" role="list">
      <li v-for="event in shown" :key="event.id" class="public-events__item">
        <EventDateBadge :date="event.date" />
        <span class="public-events__text">
          <RouterLink class="public-events__title" :to="{ name: 'event', params: { id: event.id } }">{{ event.title }}</RouterLink>
          <span class="public-events__meta">{{ event.time }} · {{ event.creator.firstName }}</span>
        </span>
      </li>
    </ul>
    <button v-if="items.length > PUBLIC_EVENTS_SHOWN" type="button" class="public-events__more" @click="showAll = true">
      Ver todos ({{ items.length }})
    </button>

    <BaseModal :open="showAll" title="Planes públicos" @close="showAll = false">
      <ul class="public-events__full" role="list">
        <li v-for="event in items" :key="event.id" class="public-events__row">
          <EventDateBadge :date="event.date" />
          <span class="public-events__text">
            <RouterLink class="public-events__title" :to="{ name: 'event', params: { id: event.id } }" @click="showAll = false">{{ event.title }}</RouterLink>
            <span class="public-events__meta">{{ event.time }} · {{ event.location }}</span>
            <span class="public-events__meta">
              Organiza {{ event.creator.firstName }} · {{ plural(event.counts.going, 'asistente', 'asistentes') }}
            </span>
          </span>
        </li>
      </ul>
    </BaseModal>
  </section>
</template>

<style lang="scss" scoped>
.public-events {
  &__list {
    margin: 0;
    padding: $space-2 $space-3;
  }

  &__empty {
    padding: $space-2 $space-3 $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: $space-2;
    padding: $space-1 0;
  }

  &__text {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
  }

  &__title {
    @include truncate;
    font-size: $fs-sm;
    font-weight: 700;
  }

  &__meta {
    @include truncate;
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__more {
    @include reset-button;
    display: block;
    padding: 0 $space-3 $space-2;
    font-size: $fs-sm;
    color: $color-link;

    &:hover {
      text-decoration: underline;
    }
  }

  &__full {
    display: flex;
    flex-direction: column;
    margin: 0;
    padding: 0;
  }

  &__row {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-2 0;

    & + & {
      border-top: 1px solid $color-border;
    }
  }
}
</style>
