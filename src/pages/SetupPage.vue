<script setup>
import { computed, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import CityPicker from '@/components/common/CityPicker.vue'
import TermsConsent from '@/components/legal/TermsConsent.vue'
import SettingsYourData from '@/components/settings/SettingsYourData.vue'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/services/errors'
import { reloadToLatestVersion } from '@/utils/pwa'
import { useToast } from '@/composables/useToast'
import { LIMITS, firstError, rules } from '@/utils/validation'
import { toDateInput } from '@/utils/time'

// What an account still needs before using YOUNGrr, asked once:
// - age (accounts from before the check, or created by an administrator);
// - a password of its own (accounts created by an administrator have a
//   temporary one, which only stops counting when it really changes);
// - name and, optionally, town (accounts created by hand);
// - accepting the current terms and privacy policy (new accounts accept them
//   at sign up; everyone accepts again when they change).
// The router sends them here until done; the database checks each step.

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
  birthDate: '',
  password: '',
  repeat: '',
  acceptedTerms: false,
})
const errors = reactive({})
const serverError = ref('')
const submitting = ref(false)

// COMPUTED
const needsAge = computed(() => auth.me?.adultConfirmed === false)
const needsPassword = computed(() => !!auth.me?.mustChangePassword)
const needsProfile = computed(() => !!auth.me?.needsSetup)
const needsTerms = computed(() => auth.needsTerms)
// Only the terms changed: whoever does not accept them can take their data and leave.
const onlyTerms = computed(() => needsTerms.value && !needsAge.value && !needsPassword.value && !needsProfile.value)
const maxBirthDate = computed(() => {
  const d = new Date()
  d.setFullYear(d.getFullYear() - LIMITS.minAge)
  return toDateInput(d)
})

// METHODS
const validateForm = () => {
  errors.birthDate = needsAge.value ? rules.adult(form.birthDate) : null
  errors.password = needsPassword.value ? rules.password(form.password) : null
  errors.repeat = needsPassword.value && form.repeat !== form.password ? 'Las contraseñas no coinciden.' : null
  errors.firstName = needsProfile.value ? firstError(rules.required(form.firstName, 'El nombre'), rules.max(form.firstName, LIMITS.name, 'El nombre')) : null
  errors.lastName = needsProfile.value ? firstError(rules.required(form.lastName, 'El apellido'), rules.max(form.lastName, LIMITS.name, 'El apellido')) : null
  errors.location = needsProfile.value ? rules.optionalLocation(form.location) : null
  errors.acceptedTerms = needsTerms.value && !form.acceptedTerms ? 'Tienes que aceptar las condiciones de uso y la política de privacidad.' : null
  return !Object.values(errors).some(Boolean)
}

const submit = async () => {
  serverError.value = ''
  if (!validateForm()) return
  submitting.value = true
  try {
    await auth.completeSetup({ ...form })
    toast.success(`Todo listo, ${auth.me.firstName}.`)
    router.replace({ name: 'home' })
  } catch (e) {
    // An old copy of the app (the PWA kept it) shows terms that are no longer
    // the current ones: get the new version instead of failing.
    if (e?.code === 'conflict' && /condiciones han cambiado/i.test(e.message ?? '')) {
      serverError.value = 'Hay una versión nueva de las condiciones. Actualizando YOUNGrr…'
      await reloadToLatestVersion()
      return
    }
    serverError.value = errorMessage(e)
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="setup panel">
    <h1 class="setup__title">Antes de empezar</h1>
    <p v-if="onlyTerms" class="setup__lead">Hemos actualizado las condiciones de uso y la política de privacidad. Para seguir, revísalas y acéptalas.</p>
    <p v-else class="setup__lead">
      YOUNGrr es solo para mayores de {{ LIMITS.minAge }} años.
      <template v-if="needsPassword">La contraseña que te han dado es provisional: elige una tuya.</template>
    </p>

    <form class="form-grid" novalidate @submit.prevent="submit">
      <div v-if="needsAge" class="field">
        <label class="field__label" for="setup-birth">Fecha de nacimiento</label>
        <input id="setup-birth" v-model="form.birthDate" class="input" type="date" :max="maxBirthDate" autocomplete="bday" :aria-invalid="!!errors.birthDate || undefined" aria-describedby="setup-birth-hint setup-birth-error" />
        <p id="setup-birth-hint" class="field__hint">Solo para comprobar tu edad: no la guardamos.</p>
        <p id="setup-birth-error" class="field__error">{{ errors.birthDate }}</p>
      </div>

      <template v-if="needsProfile">
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
          label="¿Dónde vives? Ciudad o pueblo (opcional)"
          hint="Para sugerirte los grupos de tu zona."
          :error="errors.location ?? ''"
        />
      </template>

      <template v-if="needsPassword">
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
      </template>

      <TermsConsent v-if="needsTerms" id="setup-terms" v-model="form.acceptedTerms" :error="errors.acceptedTerms ?? ''" />

      <p v-if="serverError" class="field__error" role="alert">{{ serverError }}</p>
      <button type="submit" class="btn btn--primary btn--block" :disabled="submitting">
        {{ submitting ? 'Guardando…' : onlyTerms ? 'Aceptar y seguir' : 'Empezar' }}
      </button>
    </form>

    <details v-if="onlyTerms" class="setup__leave">
      <summary>¿No quieres aceptarlas?</summary>
      <p class="setup__alt">Puedes descargar tus datos y eliminar tu cuenta.</p>
      <SettingsYourData />
    </details>

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

  &__leave summary {
    color: $color-link;
    cursor: pointer;
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
