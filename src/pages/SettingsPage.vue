<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import TabNav from '@/components/common/TabNav.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import SettingsAccount from '@/components/settings/SettingsAccount.vue'
import SettingsPrivacy from '@/components/settings/SettingsPrivacy.vue'
import SettingsNotifications from '@/components/settings/SettingsNotifications.vue'
import SettingsAppearance from '@/components/settings/SettingsAppearance.vue'
import { useUserStore } from '@/stores/user'
import { errorMessage } from '@/services/errors'

// STORES
const route = useRoute()
const user = useUserStore()

// DATA
const SECTIONS = [
  { key: 'account', label: 'Cuenta' },
  { key: 'privacy', label: 'Privacidad' },
  { key: 'notifications', label: 'Notificaciones' },
  { key: 'appearance', label: 'Apariencia' },
]
const status = ref(user.settings ? 'success' : 'loading')
const error = ref(null)

// COMPUTED
const section = computed(() => (typeof route.params.section === 'string' && route.params.section) || 'account')

// METHODS
const tabRoute = (key) => ({ name: 'settings', params: { section: key === 'account' ? undefined : key } })

const load = async () => {
  status.value = user.settings ? 'success' : 'loading'
  try {
    await user.loadSettings()
    status.value = 'success'
  } catch (e) {
    error.value = errorMessage(e)
    status.value = 'error'
  }
}

// LIFECYCLE
onMounted(load)
</script>

<template>
  <div class="settings-page">
    <h1 class="page-title settings-page__title">Configuración</h1>
    <div class="panel settings-page__panel">
      <TabNav label="Secciones de configuración" :tabs="SECTIONS" :active="section" :to="tabRoute" />
      <AsyncState :status="status" :error="error" @retry="load">
        <SettingsAccount v-if="section === 'account'" />
        <SettingsPrivacy v-else-if="section === 'privacy'" />
        <SettingsNotifications v-else-if="section === 'notifications'" />
        <SettingsAppearance v-else />
      </AsyncState>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.settings-page {
  max-width: 46rem;

  &__title {
    padding: 0 $space-4;
  }

  &__panel {
    border-radius: 0;
    border-right: 0;
    border-left: 0;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .settings-page {
    &__title {
      padding: 0;
    }

    &__panel {
      border-right: 1px solid $color-border;
      border-left: 1px solid $color-border;
      border-radius: $radius;
    }
  }
}
</style>
