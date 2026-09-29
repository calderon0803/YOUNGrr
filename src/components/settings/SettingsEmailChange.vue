<script setup>
import { reactive, ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/services/errors'
import { rules } from '@/utils/validation'

// Changing the email: asks for the password, then Supabase sends a
// confirmation link; the email only changes once it is confirmed. The answer
// does not reveal whether the new email already has an account.

// PROPS
defineProps({
  current: { type: String, default: '' },
})

// STORES
const auth = useAuthStore()

// DATA
const form = reactive({ next: '', password: '' })
const saving = ref(false)
const error = ref('')
const sent = ref('')

// METHODS
const submit = async () => {
  error.value = rules.email(form.next) ?? (form.password || auth.isLocalBackend ? '' : 'Escribe tu contraseña.')
  if (error.value) return
  saving.value = true
  try {
    await auth.changeEmail(form.password, form.next)
    sent.value = form.next.trim().toLowerCase()
    form.next = ''
    form.password = ''
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="email-change">
    <p>{{ current }}</p>
    <p v-if="sent" class="email-change__sent" role="status">
      Te hemos enviado un enlace a {{ sent }} (y un aviso a tu correo actual). El cambio se hace cuando lo abras.
    </p>
    <form class="form-grid settings-section__form" novalidate @submit.prevent="submit">
      <div class="field">
        <label class="field__label" for="email-next">Nuevo correo</label>
        <input id="email-next" v-model="form.next" class="input" type="email" inputmode="email" autocomplete="email" />
      </div>
      <div v-if="!auth.isLocalBackend" class="field">
        <label class="field__label" for="email-password">Tu contraseña</label>
        <input id="email-password" v-model="form.password" class="input" type="password" autocomplete="current-password" />
      </div>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
      <div>
        <button type="submit" class="btn btn--secondary" :disabled="saving || !form.next">
          {{ saving ? 'Enviando…' : 'Cambiar correo' }}
        </button>
      </div>
    </form>
  </div>
</template>

<style lang="scss" scoped>
@use '@/styles/partials/settings';

.email-change {
  display: flex;
  flex-direction: column;
  gap: $space-3;

  &__sent {
    font-size: $fs-sm;
    color: $color-success;
  }
}
</style>
