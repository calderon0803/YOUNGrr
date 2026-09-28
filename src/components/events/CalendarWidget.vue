<script setup>
import { computed, onMounted, ref, useId } from 'vue'
import { useRouter } from 'vue-router'
import { CalendarDays, CalendarPlus, Cake } from 'lucide-vue-next'
import EventFormDialog from '@/components/events/EventFormDialog.vue'
import { useEventsStore } from '@/stores/events'
import { useFriendsStore } from '@/stores/friends'
import { fullName } from '@/utils/text'
import { daysUntil, shortDayMonth } from '@/utils/time'

// Tuenti's "Calendario": your plans and your friends' birthdays for today,
// tomorrow and this week, plus the next ones further ahead.

// STORES
const events = useEventsStore()
const friends = useFriendsStore()
const router = useRouter()

// DATA
const titleId = useId()
const creating = ref(false)
const LATER_MAX = 3

// COMPUTED
const items = computed(() => {
  const plans = [...events.overview.invitations, ...events.overview.upcoming]
    .map((id) => events.events[id])
    .filter(Boolean)
    .map((e) => ({
      key: `e-${e.id}`,
      kind: 'event',
      date: e.date,
      sort: `${e.date}${e.time}`,
      title: e.title,
      to: { name: 'event', params: { id: e.id } },
      time: e.time,
      pending: e.myStatus === 'pending',
    }))
  const birthdays = friends.birthdays.items.map((b) => ({
    key: `b-${b.person.id}`,
    kind: 'birthday',
    date: b.date,
    sort: `${b.date}00:00`,
    title: fullName(b.person),
    to: { name: 'profile', params: { id: b.person.id } },
  }))
  return [...plans, ...birthdays]
    .map((item) => ({ ...item, days: daysUntil(item.date) }))
    .filter((item) => item.days >= 0)
    .sort((a, b) => a.sort.localeCompare(b.sort))
})

const sections = computed(() =>
  [
    { key: 'today', title: 'Hoy', items: items.value.filter((i) => i.days === 0), empty: 'No tienes ningún plan.' },
    { key: 'tomorrow', title: 'Mañana', items: items.value.filter((i) => i.days === 1), empty: 'No tienes ningún plan.' },
    { key: 'week', title: 'Esta semana', items: items.value.filter((i) => i.days > 1 && i.days < 7), empty: 'Nada más esta semana.' },
    { key: 'later', title: 'Más adelante', items: items.value.filter((i) => i.days >= 7).slice(0, LATER_MAX), empty: null },
  ].filter((s) => s.items.length || s.empty),
)

// METHODS
// Today and tomorrow need no date; the rest show it, like Tuenti ("2 de Dic").
const detail = (item, section) => {
  const date = section === 'week' || section === 'later' ? shortDayMonth(item.date) : ''
  return [date, item.kind === 'event' ? item.time : ''].filter(Boolean).join(' · ')
}

const onCreated = (event) => router.push({ name: 'event', params: { id: event.id } })

// LIFECYCLE
onMounted(() => friends.loadBirthdays())
</script>

<template>
  <section class="panel calendar" :aria-labelledby="titleId">
    <header class="calendar__head panel-title">
      <h2 :id="titleId" class="calendar__title">Calendario</h2>
      <button type="button" class="calendar__create" @click="creating = true">
        <CalendarPlus aria-hidden="true" />
        Crear evento
      </button>
    </header>

    <div v-for="section in sections" :key="section.key" class="calendar__section">
      <h3 class="calendar__day">{{ section.title }}</h3>
      <ul v-if="section.items.length" class="calendar__list" role="list">
        <li v-for="item in section.items" :key="item.key" class="calendar__item">
          <component :is="item.kind === 'event' ? CalendarDays : Cake" class="calendar__icon" aria-hidden="true" />
          <p>
            <template v-if="item.kind === 'birthday'">Cumpleaños de </template>
            <RouterLink :to="item.to">{{ item.title }}</RouterLink>
            <span v-if="detail(item, section.key)" class="calendar__detail">{{ detail(item, section.key) }}</span>
            <span v-if="item.pending" class="calendar__pending"> · Pendiente de responder</span>
          </p>
        </li>
      </ul>
      <p v-else class="calendar__empty">{{ section.empty }}</p>
    </div>

    <RouterLink class="calendar__all" :to="{ name: 'events' }">Ver todos los eventos</RouterLink>

    <EventFormDialog :open="creating" @close="creating = false" @saved="onCreated" />
  </section>
</template>

<style lang="scss" scoped>
.calendar {
  &__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: $space-2;
  }

  &__title {
    font: inherit;
  }

  &__create {
    @include reset-button;
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    font-size: $fs-xs;
    font-weight: 600;
    color: $color-link;

    svg {
      width: 0.9rem;
      height: 0.9rem;
    }

    &:hover {
      text-decoration: underline;
    }
  }

  &__section {
    padding: $space-2 $space-3 0;
  }

  &__day {
    font-size: $fs-sm;
    font-weight: 700;
    color: $color-text;
  }

  &__list {
    margin: 0;
    padding: 0;
  }

  &__item {
    display: flex;
    align-items: flex-start;
    gap: $space-2;
    padding: 0.15rem 0;
    font-size: $fs-sm;
    line-height: 1.35;
  }

  &__icon {
    flex-shrink: 0;
    width: 0.95rem;
    height: 0.95rem;
    margin-top: 0.1rem;
    color: $color-brand;
  }

  &__detail {
    margin-left: 0.3rem;
    color: $color-text-muted;
  }

  &__pending {
    font-weight: 600;
    color: $color-grr-strong;
  }

  &__empty {
    padding: 0.15rem 0;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__all {
    display: block;
    padding: $space-2 $space-3 $space-3;
    font-size: $fs-sm;
    font-weight: 600;
  }
}
</style>
