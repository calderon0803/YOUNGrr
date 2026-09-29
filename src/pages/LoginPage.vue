<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import LoginForm from '@/components/auth/LoginForm.vue'
import DemoAccounts from '@/components/auth/DemoAccounts.vue'

// STORES
const route = useRoute()

// COMPUTED
const accountDeleted = computed(() => route.query.cuenta === 'eliminada')
</script>

<template>
  <div class="auth-card panel">
    <h1 class="auth-card__title">Entrar</h1>
    <p v-if="accountDeleted" class="auth-card__notice" role="status">Tu cuenta y tus datos se han eliminado.</p>
    <p class="auth-card__lead">Tus amigos te están esperando.</p>
    <LoginForm />
    <p class="auth-card__alt"><RouterLink :to="{ name: 'forgot-password' }">¿Olvidaste tu contraseña?</RouterLink></p>
    <p class="auth-card__alt">
      ¿No tienes cuenta? YOUNGrr es solo por invitación y para mayores de 18 años: pide a un amigo que te invite.
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

  &__notice {
    padding: $space-2 $space-3;
    border-radius: $radius-sm;
    background: $color-success-soft;
    color: $color-text;
  }

  &__demo {
    padding-top: $space-4;
    border-top: 1px solid $color-border;
  }
}
</style>
