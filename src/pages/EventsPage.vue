<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { CalendarDays, Plus } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import EventCard from '@/components/events/EventCard.vue'
import EventFormDialog from '@/components/events/EventFormDialog.vue'
import { useEventsStore } from '@/stores/events'

// STORES
const events = useEventsStore()
const router = useRouter()

// DATA
const creating = ref(false)

// COMPUTED
const sections = computed(() =>
  [
    { key: 'invitations', title: 'Invitaciones pendientes', items: pick(events.overview.invitations) },
    { key: 'upcoming', title: 'Próximos', items: pick(events.overview.upcoming) },
    { key: 'past', title: 'Anteriores', items: pick(events.overview.past) },
  ].filter((s) => s.items.length),
)

// METHODS
const pick = (ids) => ids.map((id) => events.events[id]).filter(Boolean)
const onCreated = (event) => router.push({ name: 'event', params: { id: event.id } })

// LIFECYCLE
onMounted(() => events.loadEvents())
</script>

<template>
  <div class="events-page">
    <div class="events-page__head">
      <h1 class="page-title">Eventos</h1>
      <button type="button" class="btn btn--primary" @click="creating = true">
        <Plus aria-hidden="true" />
        Crear evento
      </button>
    </div>

    <AsyncState :status="events.overview.status" :error="events.overview.error" :empty="!sections.length" skeleton="block" @retry="events.loadEvents()">
      <template #empty>
        <div class="panel">
          <StateMessage :icon="CalendarDays" title="No tienes planes a la vista." text="Crea un evento e invita a tus amigos. Aquí verás también a los que te inviten.">
            <button type="button" class="btn btn--primary" @click="creating = true">Crear evento</button>
          </StateMessage>
        </div>
      </template>

      <section v-for="section in sections" :key="section.key" class="events-page__section" :aria-labelledby="`events-${section.key}`">
        <h2 :id="`events-${section.key}`" class="events-page__title">
          {{ section.title }}
          <span class="events-page__count">{{ section.items.length }}</span>
        </h2>
        <ul class="events-page__grid" role="list">
          <EventCard v-for="event in section.items" :key="event.id" :event="event" />
        </ul>
      </section>
    </AsyncState>

    <EventFormDialog :open="creating" @close="creating = false" @saved="onCreated" />
  </div>
</template>

<style lang="scss" scoped>
.events-page {
  display: flex;
  flex-direction: column;
  gap: $space-5;
  padding: 0 $space-3;

  &__head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: $space-3;
    margin-bottom: -$space-4;
  }

  &__title {
    @include section-title;
    margin-bottom: $space-2;
  }

  &__count {
    color: $color-text-soft;
  }

  &__grid {
    display: grid;
    // One column on mobile, never wider than the screen (long places are cut
    // with an ellipsis instead of widening the whole page).
    grid-template-columns: minmax(0, 1fr);
    gap: $space-3;
    margin: 0;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .events-page {
    padding: 0;

    &__grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }
}

@media (min-width: $bp-desktop) {
  .events-page__grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
</style>
