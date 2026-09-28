<script setup>
import LoginForm from '@/components/auth/LoginForm.vue'
import DemoAccounts from '@/components/auth/DemoAccounts.vue'
</script>

<template>
  <div class="auth-card panel">
    <h1 class="auth-card__title">Entrar</h1>
    <p class="auth-card__lead">Tus amigos te están esperando.</p>
    <LoginForm />
    <p class="auth-card__alt">
      ¿No tienes cuenta? <RouterLink :to="{ name: 'register' }">Crear cuenta</RouterLink>
    </p>
    <DemoAccounts class="auth-card__demo" />
  </div>
</template>

<style lang="scss" scoped>
.auth-card {
  display: flex;
  flex-direction: column;
  gap: $space-4;
  max-width: 26rem;
  margin: 0 auto;
  padding: $space-5;

  &__title {
    font-size: $fs-xl;
    font-weight: 800;
  }

  &__lead,
  &__alt {
    color: $color-text-muted;
  }

  &__lead {
    margin-top: -$space-3;
  }

  &__demo {
    padding-top: $space-4;
    border-top: 1px solid $color-border;
  }
}
</style>
