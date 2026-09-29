<script setup>
import { ref } from 'vue'
import { MailCheck } from 'lucide-vue-next'
import StateMessage from '@/components/common/StateMessage.vue'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/services/errors'
import { rules } from '@/utils/validation'

// Asks Supabase to email a recovery link. The answer is the same whether the
// email has an account or not, so nobody can find out who is registered.

// STORES
const auth = useAuthStore()

// DATA
const email = ref('')
const error = ref('')
const sending = ref(false)
const sent = ref(false)

// METHODS
const submit = async () => {
  error.value = rules.email(email.value) ?? ''
  if (error.value) return
  sending.value = true
  try {
    await auth.requestPasswordReset(email.value)
    sent.value = true
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <div class="forgot panel">
    <template v-if="sent">
      <h1 class="visually-hidden">Revisa tu correo</h1>
      <StateMessage
        :icon="MailCheck"
        title="Revisa tu correo"
        text="Si hay una cuenta con ese correo, te hemos enviado un enlace para elegir una contraseña nueva. Caduca en poco tiempo: úsalo cuanto antes."
      >
        <RouterLink class="btn btn--primary" :to="{ name: 'login' }">Volver a entrar</RouterLink>
      </StateMessage>
    </template>
    <template v-else>
      <h1 class="forgot__title">Recuperar contraseña</h1>
      <p class="forgot__lead">Escribe el correo de tu cuenta y te enviaremos un enlace para elegir una contraseña nueva.</p>
      <form class="form-grid" novalidate @submit.prevent="submit">
        <div class="field">
          <label class="field__label" for="forgot-email">Correo electrónico</label>
          <input
            id="forgot-email"
            v-model="email"
            class="input"
            type="email"
            inputmode="email"
            autocomplete="email"
            :aria-invalid="!!error || undefined"
            aria-describedby="forgot-error"
          />
          <p id="forgot-error" class="field__error" role="alert">{{ error }}</p>
        </div>
        <button type="submit" class="btn btn--primary btn--block" :disabled="sending">
          {{ sending ? 'Enviando…' : 'Enviar enlace' }}
        </button>
      </form>
      <p class="forgot__alt"><RouterLink :to="{ name: 'login' }">Volver a entrar</RouterLink></p>
    </template>
  </div>
</template>

<style lang="scss" scoped>
.forgot {
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
}
</style>
