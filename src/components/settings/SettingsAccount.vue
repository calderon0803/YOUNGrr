<script setup>
import { onMounted, reactive, ref } from 'vue'
import InstallCard from '@/components/common/InstallCard.vue'
import SettingsEmailChange from '@/components/settings/SettingsEmailChange.vue'
import SettingsYourData from '@/components/settings/SettingsYourData.vue'
import { useAuthStore } from '@/stores/auth'
import { useUiStore } from '@/stores/ui'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { LIMITS } from '@/utils/validation'

// STORES
const auth = useAuthStore()
const ui = useUiStore()
const toast = useToast()

// DATA
const email = ref('')
const password = reactive({ current: '', next: '' })
const saving = ref(false)
const error = ref('')

// METHODS
const changePassword = async () => {
  saving.value = true
  error.value = ''
  try {
    await auth.changePassword(password.current, password.next)
    password.current = ''
    password.next = ''
    toast.success('Contraseña actualizada.')
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    saving.value = false
  }
}

const resetDemo = async () => {
  const ok = await ui.confirm({
    title: 'Restablecer datos de demostración',
    message: 'Se borrará todo lo que hayas hecho en este navegador y volverán los datos de ejemplo.',
    confirmLabel: 'Restablecer',
    danger: true,
  })
  if (ok) await auth.resetDemoData()
}

// LIFECYCLE
onMounted(async () => {
  email.value = await auth.loadEmail()
})
</script>

<template>
  <div class="settings-section">
    <section class="settings-section__block" aria-labelledby="acc-email">
      <h2 id="acc-email" class="settings-section__title">Correo electrónico</h2>
      <SettingsEmailChange :current="email" />
    </section>

    <section class="settings-section__block" aria-labelledby="acc-password">
      <h2 id="acc-password" class="settings-section__title">Contraseña</h2>
      <form class="form-grid settings-section__form" novalidate @submit.prevent="changePassword">
        <input class="visually-hidden" type="email" autocomplete="username" :value="email" tabindex="-1" aria-hidden="true" readonly />
        <div class="field">
          <label class="field__label" for="pw-current">Contraseña actual</label>
          <input id="pw-current" v-model="password.current" class="input" type="password" autocomplete="current-password" />
          <p v-if="auth.isLocalBackend" class="field__hint">Si es una cuenta de demostración, déjalo vacío.</p>
        </div>
        <div class="field">
          <label class="field__label" for="pw-next">Nueva contraseña</label>
          <input id="pw-next" v-model="password.next" class="input" type="password" autocomplete="new-password" />
          <p class="field__hint">Mínimo {{ LIMITS.passwordMin }} caracteres.</p>
        </div>
        <p v-if="error" class="field__error" role="alert">{{ error }}</p>
        <div>
          <button type="submit" class="btn btn--primary" :disabled="saving || !password.next">
            {{ saving ? 'Guardando…' : 'Cambiar contraseña' }}
          </button>
        </div>
      </form>
    </section>

    <section class="settings-section__block" aria-labelledby="acc-app">
      <h2 id="acc-app" class="settings-section__title">Aplicación</h2>
      <InstallCard />
    </section>

    <section v-if="auth.isLocalBackend" class="settings-section__block" aria-labelledby="acc-demo">
      <h2 id="acc-demo" class="settings-section__title">Datos de demostración</h2>
      <p class="muted">YOUNGrr está funcionando con datos guardados en este navegador.</p>
      <div>
        <button type="button" class="btn btn--secondary" @click="resetDemo">Restablecer datos de demostración</button>
      </div>
    </section>

    <section class="settings-section__block" aria-labelledby="acc-data">
      <h2 id="acc-data" class="settings-section__title">Tus datos</h2>
      <SettingsYourData />
    </section>

    <section class="settings-section__block" aria-labelledby="acc-session">
      <h2 id="acc-session" class="settings-section__title">Sesión</h2>
      <div>
        <button type="button" class="btn btn--secondary" @click="auth.logout()">Salir de YOUNGrr</button>
      </div>
    </section>
  </div>
</template>

<style lang="scss" scoped>
@use '@/styles/partials/settings';
</style>
