<script setup>
// Section tabs rendered as links (?tab=...), so each tab has its own URL.

// PROPS
defineProps({
  /** [{ key, label, count? }] */
  tabs: { type: Array, required: true },
  active: { type: String, required: true },
  label: { type: String, required: true },
  /** Builds the route for a tab key. */
  to: { type: Function, required: true },
})
</script>

<template>
  <nav class="tabs" :aria-label="label">
    <ul class="tabs__list" role="list">
      <li v-for="tab in tabs" :key="tab.key">
        <RouterLink
          class="tabs__tab"
          :class="{ 'tabs__tab--active': tab.key === active }"
          :to="to(tab.key)"
          :aria-current="tab.key === active ? 'page' : undefined"
          replace
        >
          {{ tab.label }}
          <span v-if="tab.count" class="tabs__count">{{ tab.count }}</span>
        </RouterLink>
      </li>
    </ul>
  </nav>
</template>

<style lang="scss" scoped>
.tabs {
  overflow-x: auto;
  scrollbar-width: none;
  border-bottom: 1px solid $color-border;

  &__list {
    display: flex;
    gap: $space-1;
    margin: 0;
    padding: 0 $space-2;
  }

  &__tab {
    display: inline-flex;
    align-items: center;
    gap: $space-2;
    padding: $space-3 $space-3;
    border-bottom: 3px solid transparent;
    color: $color-text-muted;
    font-weight: 600;
    white-space: nowrap;

    &:hover {
      color: $color-text;
      text-decoration: none;
    }

    &--active {
      color: $color-brand-strong;
      border-bottom-color: $color-brand;
    }
  }

  &__count {
    padding: 0 0.4rem;
    border-radius: $radius-pill;
    background: $color-grr;
    color: $color-on-brand;
    font-size: $fs-xs;
    font-weight: 700;
    line-height: 1.35;
  }
}
</style>
