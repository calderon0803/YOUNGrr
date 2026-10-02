<script setup>
import AppLogo from '@/components/common/AppLogo.vue'
import { useAuthStore } from '@/stores/auth'

// STORES
// Signed in (completing the profile), the sign in links make no sense.
const auth = useAuthStore()
</script>

<template>
  <div class="auth">
    <header class="auth__bar">
      <RouterLink class="auth__brand" to="/" aria-label="YOUNGrr, portada">
        <AppLogo on-dark size="md" />
      </RouterLink>
      <nav v-if="!auth.isAuthenticated" class="auth__links" aria-label="Cuenta">
        <RouterLink :to="{ name: 'login' }">Entrar</RouterLink>
        <RouterLink :to="{ name: 'register' }">Crear cuenta</RouterLink>
      </nav>
    </header>
    <main id="main" class="auth__main">
      <slot />
    </main>
    <footer class="auth__footer">
      <AppLogo size="sm" />
      <span>Una red social para ver qué hacen tus amigos. Sin seguidores, sin algoritmos.</span>
      <nav class="auth__legal" aria-label="Información legal">
        <RouterLink :to="{ name: 'terms' }">Condiciones de uso</RouterLink>
        <RouterLink :to="{ name: 'privacy' }">Privacidad</RouterLink>
        <RouterLink :to="{ name: 'legal-notice' }">Aviso legal</RouterLink>
        <RouterLink :to="{ name: 'illegal-report' }">Avisar de contenido ilegal</RouterLink>
      </nav>
    </footer>
  </div>
</template>

<style lang="scss" scoped>
.auth {
  display: flex;
  flex-direction: column;
  min-height: 100dvh;
  background: $color-bg;

  &__bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: $space-4;
    min-height: $header-height;
    padding: env(safe-area-inset-top) $space-4 0;
    background: $color-header-bg;
  }

  &__brand:hover {
    text-decoration: none;
  }

  &__links {
    display: flex;
    gap: $space-4;

    a {
      color: $color-on-brand;
      font-weight: 600;

      &.router-link-active {
        text-decoration: underline;
        text-underline-offset: 0.3em;
      }
    }
  }

  &__main {
    flex: 1;
    width: 100%;
    max-width: $content-max;
    margin: 0 auto;
    padding: $space-5 $space-4 $space-8;
  }

  &__footer {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: center;
    gap: $space-2 $space-3;
    padding: $space-5 $space-4 calc(#{$space-5} + env(safe-area-inset-bottom));
    border-top: 1px solid $color-border;
    font-size: $fs-sm;
    color: $color-text-muted;
    text-align: center;
  }

  &__legal {
    display: flex;
    gap: $space-3;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .auth {
    &__bar {
      padding: 0 $space-6;
    }

    &__main {
      padding: $space-8 $space-6 $space-10;
    }
  }
}
</style>
