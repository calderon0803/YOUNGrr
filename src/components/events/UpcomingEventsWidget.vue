<script setup>
import { computed } from 'vue'
import EventDateBadge from '@/components/events/EventDateBadge.vue'
import { useEventsStore } from '@/stores/events'

// STORES
const events = useEventsStore()

// DATA
const STATUS_LABEL = { going: 'Asistirás', maybe: 'Quizás', declined: 'No asistirás', pending: 'Pendiente de responder' }

// COMPUTED
const items = computed(() =>
  [...events.overview.invitations, ...events.overview.upcoming]
    .map((id) => events.events[id])
    .filter(Boolean)
    .sort((a, b) => `${a.date}${a.time}`.localeCompare(`${b.date}${b.time}`))
    .slice(0, 3),
)
</script>

<template>
  <section v-if="items.length" class="panel widget" aria-labelledby="events-widget-title">
    <h2 id="events-widget-title" class="panel-title">Próximos planes</h2>
    <ul class="widget__list" role="list">
      <li v-for="event in items" :key="event.id" class="widget__item">
        <EventDateBadge :date="event.date" />
        <div class="widget__body">
          <RouterLink class="upcoming__title" :to="{ name: 'event', params: { id: event.id } }">{{ event.title }}</RouterLink>
          <p class="widget__sub">
            {{ event.time }} · <span :class="{ 'upcoming__pending': event.myStatus === 'pending' }">{{ STATUS_LABEL[event.myStatus] }}</span>
          </p>
        </div>
      </li>
    </ul>
    <RouterLink class="widget__all" :to="{ name: 'events' }">Ver todos los eventos</RouterLink>
  </section>
</template>

<style lang="scss" scoped>
@use '@/styles/partials/widget';

.upcoming {
  &__title {
    font-weight: 700;
    color: $color-text;
  }

  &__pending {
    font-weight: 600;
    color: $color-grr-strong;
  }
}
</style>
