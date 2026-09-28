<script setup>
import { fullName } from '@/utils/text'

// PROPS
defineProps({
  person: { type: Object, required: true },
})
</script>

<template>
  <RouterLink class="person-link" :to="{ name: 'profile', params: { id: person.id } }">{{ fullName(person) }}</RouterLink>
</template>

<style lang="scss" scoped>
.person-link {
  font-weight: 700;
  color: $color-brand-strong;
}
</style>
