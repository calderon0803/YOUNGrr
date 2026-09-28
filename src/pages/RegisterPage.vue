<script setup>
import { computed, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { MailCheck, MailQuestionMark } from 'lucide-vue-next'
import CityPicker from '@/components/common/CityPicker.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import { useAuthStore } from '@/stores/auth'
import { invitationsService } from '@/services/invitations.service'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { LIMITS, firstError, rules } from '@/utils/validation'
import { fullName } from '@/utils/text'

// Sign up is by invitation only: the page needs the personal link (?invite=)
// a registered friend sent, and the account is created with that email.

// STORES
const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const toast = useToast()

// DATA
const form = reactive({ firstName: '', lastName: '', email: '', password: '', location: null })
const errors = reactive({})
const serverError = ref('')
const submitting = ref(false)
/** Set when Supabase asks the user to confirm their email first. */
const confirmEmail = ref('')
/** 'checking' | 'valid' | 'invalid' | 'none' */
const inviteStatus = ref('checking')
const invitation = ref(null)

// COMPUTED
const inviteToken = computed(() => (typeof route.query.invite === 'string' ? route.query.invite : ''))

// METHODS
const validateForm = () => {
  errors.firstName = firstError(rules.required(form.firstName, 'El nombre'), rules.max(form.firstName, LIMITS.name, 'El nombre'))
  errors.lastName = firstError(rules.required(form.lastName, 'El apellido'), rules.max(form.lastName, LIMITS.name, 'El apellido'))
  errors.email = rules.email(form.email)
  errors.password = rules.password(form.password)
  errors.location = rules.location(form.location)
  return !Object.values(errors).some(Boolean)
}

const submit = async () => {
  serverError.value = ''
  if (!validateForm()) return
  submitting.value = true
  try {
    const { needsConfirmation } = await auth.register({ ...form, email: invitation.value.email, inviteToken: inviteToken.value })
    if (needsConfirmation) {
      confirmEmail.value = form.email.trim().toLowerCase()
      return
    }
    toast.success(`Bienvenido a YOUNGrr. Ya eres amigo de ${invitation.value.inviter.firstName}.`)
    router.replace({ name: 'home' })
  } catch (e) {
    serverError.value = errorMessage(e)
  } finally {
    submitting.value = false
  }
}

const checkInvitation = async (token) => {
  if (!token) {
    inviteStatus.value = 'none'
    return
  }
  inviteStatus.value = 'checking'
  try {
    invitation.value = await invitationsService.checkInvitation(token)
    inviteStatus.value = invitation.value ? 'valid' : 'invalid'
    if (invitation.value) form.email = invitation.value.email
  } catch {
    inviteStatus.value = 'invalid'
  }
}

// WATCHERS
watch(inviteToken, checkInvitation, { immediate: true })
</script>

<template>
  <div v-if="confirmEmail" class="register panel">
    <h1 class="visually-hidden">Confirma tu correo</h1>
    <StateMessage
      :icon="MailCheck"
      title="Revisa tu correo"
      :text="`Te hemos enviado un enlace a ${confirmEmail}. Ábrelo para confirmar tu cuenta y después entra en YOUNGrr.`"
    >
      <RouterLink class="btn btn--primary" :to="{ name: 'login' }">Ir a entrar</RouterLink>
    </StateMessage>
  </div>
  <div v-else-if="inviteStatus === 'checking'" class="register panel" aria-busy="true">
    <h1 class="visually-hidden">Crear cuenta</h1>
    <p class="register__lead">Comprobando tu invitación…</p>
  </div>
  <div v-else-if="inviteStatus !== 'valid'" class="register panel">
    <h1 class="visually-hidden">Crear cuenta</h1>
    <StateMessage
      :icon="MailQuestionMark"
      :title="inviteStatus === 'none' ? 'YOUNGrr es solo por invitación' : 'Esta invitación no es válida'"
      :text="
        inviteStatus === 'none'
          ? 'Para crear una cuenta necesitas que un amigo que ya esté en YOUNGrr te invite. Te enviará un enlace personal.'
          : 'Puede que ya se haya usado, que haya caducado o que la hayan cancelado. Pide a tu amigo que te invite de nuevo.'
      "
    >
      <RouterLink class="btn btn--primary" :to="{ name: 'login' }">Ya tengo cuenta</RouterLink>
    </StateMessage>
  </div>
  <div v-else class="register panel">
    <h1 class="register__title">Crear cuenta</h1>
    <p class="register__invited">
      <UserAvatar :person="invitation.inviter" size="sm" />
      <span><strong>{{ fullName(invitation.inviter) }}</strong> te ha invitado a YOUNGrr.</span>
    </p>
    <p class="register__lead">YOUNGrr es para tus amigos de verdad. Usa tu nombre real para que te encuentren.</p>

    <form class="form-grid" novalidate @submit.prevent="submit">
      <div class="register__row">
        <div class="field">
          <label class="field__label" for="reg-first">Nombre</label>
          <input id="reg-first" v-model="form.firstName" class="input" autocomplete="given-name" :aria-invalid="!!errors.firstName || undefined" aria-describedby="reg-first-error" />
          <p id="reg-first-error" class="field__error">{{ errors.firstName }}</p>
        </div>
        <div class="field">
          <label class="field__label" for="reg-last">Apellido</label>
          <input id="reg-last" v-model="form.lastName" class="input" autocomplete="family-name" :aria-invalid="!!errors.lastName || undefined" aria-describedby="reg-last-error" />
          <p id="reg-last-error" class="field__error">{{ errors.lastName }}</p>
        </div>
      </div>
      <div class="field">
        <label class="field__label" for="reg-email">Correo electrónico</label>
        <input id="reg-email" v-model="form.email" class="input" type="email" autocomplete="email" readonly aria-describedby="reg-email-hint reg-email-error" />
        <p id="reg-email-hint" class="field__hint">Es el correo al que te han invitado.</p>
        <p id="reg-email-error" class="field__error">{{ errors.email }}</p>
      </div>
      <div class="field">
        <label class="field__label" for="reg-password">Contraseña</label>
        <input id="reg-password" v-model="form.password" class="input" type="password" autocomplete="new-password" :aria-invalid="!!errors.password || undefined" aria-describedby="reg-password-hint reg-password-error" />
        <p id="reg-password-hint" class="field__hint">Mínimo {{ LIMITS.passwordMin }} caracteres.</p>
        <p id="reg-password-error" class="field__error">{{ errors.password }}</p>
      </div>
      <CityPicker
        v-model="form.location"
        label="¿Dónde vives? Ciudad o pueblo"
        hint="Se usa para «Cerca de ti». Solo se muestra el nombre del lugar, nunca tu ubicación exacta."
        :error="errors.location ?? ''"
      />

      <p v-if="serverError" class="field__error" role="alert">{{ serverError }}</p>
      <button type="submit" class="btn btn--primary btn--block" :disabled="submitting">
        {{ submitting ? 'Creando cuenta…' : 'Crear cuenta' }}
      </button>
    </form>

    <p class="register__alt">¿Ya tienes cuenta? <RouterLink :to="{ name: 'login' }">Entrar</RouterLink></p>
  </div>
</template>

<style lang="scss" scoped>
.register {
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

  &__invited {
    display: flex;
    align-items: center;
    gap: $space-2;
    margin-top: -$space-2;
  }

  &__row {
    display: grid;
    gap: $space-4;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .register__row {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
