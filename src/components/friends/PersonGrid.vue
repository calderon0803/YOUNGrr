<script setup>
import PersonCard from '@/components/friends/PersonCard.vue'

// PROPS
defineProps({
  people: { type: Array, required: true },
  label: { type: String, required: true },
  showActions: { type: Boolean, default: true },
})
</script>

<template>
  <ul class="person-grid" role="list" :aria-label="label">
    <PersonCard v-for="person in people" :key="person.id" :person="person" :show-action="showActions" />
  </ul>
</template>

<style lang="scss" scoped>
.person-grid {
  display: grid;
  margin: 0;

  > :deep(li + li) {
    border-top: 1px solid $color-border;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .person-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));

    > :deep(li + li) {
      border-top: 0;
    }

    > :deep(li) {
      border-bottom: 1px solid $color-border;
    }
  }
}
</style>
