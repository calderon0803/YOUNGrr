<script setup>
import { useUserStore } from '@/stores/user'

// STORES
const user = useUserStore()

// DATA
const THEMES = [
  { value: 'system', label: 'Automático', hint: 'Sigue la configuración de tu dispositivo.' },
  { value: 'light', label: 'Claro', hint: '' },
  { value: 'dark', label: 'Oscuro', hint: '' },
]

// METHODS
const choose = (value) => {
  const next = structuredClone(user.settings)
  next.appearance.theme = value
  user.updateSettings(next, 'Tema cambiado.')
}
</script>

<template>
  <div class="settings-section">
    <section class="settings-section__block">
      <fieldset class="settings-section__options">
        <legend class="settings-section__title">Tema</legend>
        <label v-for="theme in THEMES" :key="theme.value" class="settings-section__option">
          <input type="radio" name="theme" :value="theme.value" :checked="user.settings.appearance.theme === theme.value" @change="choose(theme.value)" />
          <span class="settings-section__option-text">
            <span>{{ theme.label }}</span>
            <span v-if="theme.hint" class="settings-section__option-hint">{{ theme.hint }}</span>
          </span>
        </label>
      </fieldset>
    </section>
  </div>
</template>

<style lang="scss" scoped>
@use '@/styles/partials/settings';
</style>
