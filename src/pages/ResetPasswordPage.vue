<script setup>
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { KeyRound } from 'lucide-vue-next'
import StateMessage from '@/components/common/StateMessage.vue'
import { useAuthStore } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'

// Opened from the recovery email: Supabase signs the person in only for this.
// After the change, every other session of the account is closed.

// STORES
const auth = useAuthStore()
const router = useRouter()
const toast = useToast()

// DATA
/** 'checking' | 'ready' | 'invalid' */
const state = ref('checking')
const form = reactive({ password: '', repeat: '' })
const errors = reactive({})
const saving = ref(false)
const serverError = ref('')

// METHODS
const submit = async () => {
  errors.password = rules.password(form.password)
  errors.repeat = form.repeat === form.password ? null : 'Las contraseñas no coinciden.'
  serverError.value = ''
  if (errors.password || errors.repeat) return
  saving.value = true
  try {
    await auth.completePasswordReset(form.password)
    toast.success('Contraseña cambiada. Hemos cerrado tus otras sesiones.')
    router.replace({ name: 'home' })
  } catch (e) {
    serverError.value = errorMessage(e)
  } finally {
    saving.value = false
  }
}

// LIFECYCLE
onMounted(async () => {
  try {
    state.value = (await auth.hasRecoverySession()) ? 'ready' : 'invalid'
  } catch {
    state.value = 'invalid'
  }
})
</script>

<template>
  <div class="reset panel">
    <h1 v-if="state !== 'ready'" class="visually-hidden">Nueva contraseña</h1>
    <p v-if="state === 'checking'" class="reset__lead" aria-busy="true">Comprobando el enlace…</p>
    <StateMessage
      v-else-if="state === 'invalid'"
      :icon="KeyRound"
      title="El enlace no es válido o ha caducado"
      text="Pide uno nuevo y ábrelo desde el mismo navegador."
    >
      <RouterLink class="btn btn--primary" :to="{ name: 'forgot-password' }">Pedir otro enlace</RouterLink>
    </StateMessage>
    <template v-else>
      <h1 class="reset__title">Elige una contraseña nueva</h1>
      <form class="form-grid" novalidate @submit.prevent="submit">
        <div class="field">
          <label class="field__label" for="reset-password">Contraseña nueva</label>
          <input id="reset-password" v-model="form.password" class="input" type="password" autocomplete="new-password" :aria-invalid="!!errors.password || undefined" aria-describedby="reset-password-hint reset-password-error" />
          <p id="reset-password-hint" class="field__hint">Mínimo {{ LIMITS.passwordMin }} caracteres.</p>
          <p id="reset-password-error" class="field__error">{{ errors.password }}</p>
        </div>
        <div class="field">
          <label class="field__label" for="reset-repeat">Repite la contraseña</label>
          <input id="reset-repeat" v-model="form.repeat" class="input" type="password" autocomplete="new-password" :aria-invalid="!!errors.repeat || undefined" aria-describedby="reset-repeat-error" />
          <p id="reset-repeat-error" class="field__error">{{ errors.repeat }}</p>
        </div>
        <p v-if="serverError" class="field__error" role="alert">{{ serverError }}</p>
        <button type="submit" class="btn btn--primary btn--block" :disabled="saving">
          {{ saving ? 'Guardando…' : 'Guardar contraseña' }}
        </button>
      </form>
    </template>
  </div>
</template>

<style lang="scss" scoped>
.reset {
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

  &__lead {
    color: $color-text-muted;
  }
}
</style>
