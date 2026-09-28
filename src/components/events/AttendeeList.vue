<script setup>
import { computed } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'

// PROPS
const props = defineProps({
  members: { type: Array, required: true },
})

// DATA
const GROUPS = [
  { status: 'going', label: 'Asistirán' },
  { status: 'maybe', label: 'Quizás' },
  { status: 'pending', label: 'Pendientes' },
  { status: 'declined', label: 'No asistirán' },
]

// COMPUTED
const groups = computed(() =>
  GROUPS.map((g) => ({ ...g, people: props.members.filter((m) => m.status === g.status).map((m) => m.person) })).filter((g) => g.people.length),
)
</script>

<template>
  <div class="attendees">
    <section v-for="group in groups" :key="group.status" class="attendees__group" :aria-labelledby="`att-${group.status}`">
      <h3 :id="`att-${group.status}`" class="attendees__title">
        {{ group.label }} <span class="attendees__count">{{ group.people.length }}</span>
      </h3>
      <ul class="attendees__list" role="list">
        <li v-for="person in group.people" :key="person.id" class="attendees__person">
          <UserAvatar :person="person" size="sm" />
          <PersonLink :person="person" />
        </li>
      </ul>
    </section>
  </div>
</template>

<style lang="scss" scoped>
.attendees {
  display: flex;
  flex-direction: column;
  gap: $space-4;

  &__title {
    @include section-title;
    margin-bottom: $space-2;
  }

  &__count {
    color: $color-text-soft;
  }

  &__list {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(10rem, 1fr));
    gap: $space-2;
    margin: 0;
  }

  &__person {
    display: flex;
    align-items: center;
    gap: $space-2;
    min-width: 0;
    font-size: $fs-sm;
  }
}
</style>
