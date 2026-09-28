<script setup>
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/services/errors'

// STORES
const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

// DATA
const form = reactive({ email: '', password: '' })
const error = ref('')
const submitting = ref(false)

// METHODS
const submit = async () => {
  error.value = ''
  submitting.value = true
  try {
    await auth.login(form.email, form.password)
    router.replace(typeof route.query.next === 'string' ? route.query.next : { name: 'home' })
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <form class="form-grid" novalidate @submit.prevent="submit">
    <div class="field">
      <label class="field__label" for="login-email">Correo electrónico</label>
      <input
        id="login-email"
        v-model="form.email"
        class="input"
        type="email"
        autocomplete="email"
        inputmode="email"
        required
        :aria-invalid="!!error || undefined"
        aria-describedby="login-error"
      />
    </div>
    <div class="field">
      <label class="field__label" for="login-password">Contraseña</label>
      <input
        id="login-password"
        v-model="form.password"
        class="input"
        type="password"
        autocomplete="current-password"
        required
        :aria-invalid="!!error || undefined"
        aria-describedby="login-error"
      />
    </div>
    <p id="login-error" class="field__error" role="alert">{{ error }}</p>
    <button type="submit" class="btn btn--primary btn--block" :disabled="submitting">
      {{ submitting ? 'Entrando…' : 'Entrar' }}
    </button>
  </form>
</template>
