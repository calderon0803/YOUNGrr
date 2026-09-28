<script setup>
import { onMounted, useId } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import { useFriendsStore } from '@/stores/friends'
import { eventDateTime } from '@/utils/time'

// Friends' birthdays in the coming days, like Tuenti's home sidebar.

// STORES
const friends = useFriendsStore()

// DATA
const titleId = useId()
const dayMonth = new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'long' })

// METHODS
const when = (b) => {
  if (b.daysLeft === 0) return 'hoy'
  if (b.daysLeft === 1) return 'mañana'
  return `el ${dayMonth.format(eventDateTime(b.date, '00:00'))}`
}

// LIFECYCLE
onMounted(() => friends.loadBirthdays())
</script>

<template>
  <section v-if="friends.birthdays.items.length" class="panel widget" :aria-labelledby="titleId">
    <h2 :id="titleId" class="panel-title">Cumpleaños</h2>
    <ul class="widget__list" role="list">
      <li v-for="b in friends.birthdays.items.slice(0, 5)" :key="b.person.id" class="widget__item birthdays__item">
        <UserAvatar :person="b.person" size="sm" />
        <p class="widget__body">
          <PersonLink :person="b.person" />
          <span class="widget__sub" :class="{ 'birthdays__today': b.daysLeft === 0 }"> cumple años {{ when(b) }}</span>
        </p>
      </li>
    </ul>
  </section>
</template>

<style lang="scss" scoped>
@use '@/styles/partials/widget';

.birthdays {
  &__item {
    align-items: center;
  }

  &__today {
    font-weight: 700;
    color: $color-grr-strong;
  }
}
</style>
