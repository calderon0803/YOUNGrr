<script setup>
// PROPS
defineProps({
  count: { type: Number, default: 0 },
  /** Accessible description, e.g. "notificaciones sin leer". */
  label: { type: String, required: true },
})
</script>

<template>
  <span v-if="count > 0" class="badge">
    {{ count > 99 ? '99+' : count }}
    <span class="visually-hidden">{{ label }}</span>
  </span>
</template>

<style lang="scss" scoped>
.badge {
  display: inline-grid;
  place-items: center;
  min-width: 1.15rem;
  height: 1.15rem;
  padding: 0 0.3rem;
  border-radius: $radius-pill;
  background: $color-grr;
  color: $color-on-brand;
  font-size: 0.6875rem;
  font-weight: 700;
  line-height: 1;
}
</style>
