<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import CityPicker from '@/components/common/CityPicker.vue'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { LIMITS, firstError, rules } from '@/utils/validation'

// First sign in of an account created by hand: it came with a temporary name
// and password, so before anything else the person writes their real name,
// their town and a password of their own. The router sends them here until done.

// STORES
const auth = useAuthStore()
const router = useRouter()
const toast = useToast()

// DATA
// "-" is the placeholder surname of accounts created by hand.
const real = (value) => (value && value !== '-' ? value : '')
const form = reactive({
  firstName: real(auth.me?.firstName),
  lastName: real(auth.me?.lastName),
  location: null,
  password: '',
  repeat: '',
})
const errors = reactive({})
const serverError = ref('')
const submitting = ref(false)

// METHODS
const validateForm = () => {
  errors.firstName = firstError(rules.required(form.firstName, 'El nombre'), rules.max(form.firstName, LIMITS.name, 'El nombre'))
  errors.lastName = firstError(rules.required(form.lastName, 'El apellido'), rules.max(form.lastName, LIMITS.name, 'El apellido'))
  errors.location = rules.location(form.location)
  errors.password = rules.password(form.password)
  errors.repeat = form.repeat === form.password ? null : 'Las contraseñas no coinciden.'
  return !Object.values(errors).some(Boolean)
}

const submit = async () => {
  serverError.value = ''
  if (!validateForm()) return
  submitting.value = true
  try {
    await auth.completeSetup({ firstName: form.firstName, lastName: form.lastName, location: form.location, password: form.password })
    toast.success(`Todo listo, ${auth.me.firstName}. Bienvenido a YOUNGrr.`)
    router.replace({ name: 'home' })
  } catch (e) {
    serverError.value = errorMessage(e)
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="setup panel">
    <h1 class="setup__title">Completa tu perfil</h1>
    <p class="setup__lead">
      Antes de empezar, pon tu nombre real para que tus amigos te encuentren y elige una contraseña tuya: la que te han dado es
      provisional.
    </p>

    <form class="form-grid" novalidate @submit.prevent="submit">
      <div class="setup__row">
        <div class="field">
          <label class="field__label" for="setup-first">Nombre</label>
          <input id="setup-first" v-model="form.firstName" class="input" autocomplete="given-name" :aria-invalid="!!errors.firstName || undefined" aria-describedby="setup-first-error" />
          <p id="setup-first-error" class="field__error">{{ errors.firstName }}</p>
        </div>
        <div class="field">
          <label class="field__label" for="setup-last">Apellido</label>
          <input id="setup-last" v-model="form.lastName" class="input" autocomplete="family-name" :aria-invalid="!!errors.lastName || undefined" aria-describedby="setup-last-error" />
          <p id="setup-last-error" class="field__error">{{ errors.lastName }}</p>
        </div>
      </div>

      <CityPicker
        v-model="form.location"
        label="¿Dónde vives? Ciudad o pueblo"
        hint="Se usa para «Cerca de ti». Solo se muestra el nombre del lugar, nunca tu ubicación exacta."
        :error="errors.location ?? ''"
      />

      <div class="field">
        <label class="field__label" for="setup-password">Contraseña nueva</label>
        <input id="setup-password" v-model="form.password" class="input" type="password" autocomplete="new-password" :aria-invalid="!!errors.password || undefined" aria-describedby="setup-password-hint setup-password-error" />
        <p id="setup-password-hint" class="field__hint">Mínimo {{ LIMITS.passwordMin }} caracteres.</p>
        <p id="setup-password-error" class="field__error">{{ errors.password }}</p>
      </div>
      <div class="field">
        <label class="field__label" for="setup-repeat">Repite la contraseña</label>
        <input id="setup-repeat" v-model="form.repeat" class="input" type="password" autocomplete="new-password" :aria-invalid="!!errors.repeat || undefined" aria-describedby="setup-repeat-error" />
        <p id="setup-repeat-error" class="field__error">{{ errors.repeat }}</p>
      </div>

      <p v-if="serverError" class="field__error" role="alert">{{ serverError }}</p>
      <button type="submit" class="btn btn--primary btn--block" :disabled="submitting">
        {{ submitting ? 'Guardando…' : 'Empezar' }}
      </button>
    </form>

    <p class="setup__alt">¿No eres tú? <button type="button" class="setup__logout" @click="auth.logout()">Salir</button></p>
  </div>
</template>

<style lang="scss" scoped>
.setup {
  display: flex;
  flex-direction: column;
  gap: $space-4;
  max-width: 30rem;
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

  &__row {
    display: grid;
    gap: $space-4;
  }

  &__logout {
    @include reset-button;
    color: $color-link;

    &:hover {
      text-decoration: underline;
    }
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .setup__row {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
