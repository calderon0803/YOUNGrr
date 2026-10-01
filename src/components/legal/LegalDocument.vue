<script setup>
import { LEGAL } from '@/config/app'

// Frame shared by the legal pages: title, version date, readable typography
// for the text in the slot and links to the other legal pages.

// PROPS
defineProps({
  title: { type: String, required: true },
})
</script>

<template>
  <article class="panel legal">
    <header class="legal__head">
      <h1 class="legal__title">{{ title }}</h1>
      <p class="legal__meta">Versión del {{ LEGAL.updatedOn }}</p>
    </header>
    <div class="legal__body">
      <slot />
    </div>
    <footer class="legal__foot">
      <RouterLink :to="{ name: 'terms' }">Condiciones de uso</RouterLink>
      <RouterLink :to="{ name: 'privacy' }">Política de privacidad</RouterLink>
      <RouterLink :to="{ name: 'legal-notice' }">Aviso legal</RouterLink>
      <RouterLink :to="{ name: 'illegal-report' }">Avisar de contenido ilegal</RouterLink>
      <RouterLink :to="{ name: 'credits' }">Créditos</RouterLink>
    </footer>
  </article>
</template>

<style lang="scss" scoped>
.legal {
  max-width: 46rem;
  margin: 0 auto;
  padding: $space-5 $space-4;

  &__title {
    font-size: $fs-xl;
    font-weight: 800;
  }

  &__meta {
    margin-top: $space-1;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__body {
    display: flex;
    flex-direction: column;
    gap: $space-3;
    margin-top: $space-5;
    line-height: 1.6;

    :deep(h2) {
      margin-top: $space-4;
      font-size: $fs-lg;
      font-weight: 700;
    }

    :deep(ul) {
      display: flex;
      flex-direction: column;
      gap: $space-1;
      margin: 0;
      padding-left: $space-5;
      list-style: disc;
    }

    :deep(table) {
      width: 100%;
      border-collapse: collapse;
      font-size: $fs-sm;
    }

    :deep(th),
    :deep(td) {
      padding: $space-2;
      border-bottom: 1px solid $color-border;
      text-align: left;
      vertical-align: top;
    }
  }

  &__foot {
    display: flex;
    flex-wrap: wrap;
    gap: $space-4;
    margin-top: $space-6;
    padding-top: $space-4;
    border-top: 1px solid $color-border;
    font-size: $fs-sm;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .legal {
    padding: $space-6;
  }
}
</style>
