<script setup>
import { useUserStore } from '@/stores/user'

// STORES
const user = useUserStore()

// DATA
const OPTIONS = [
  { key: 'grr', label: 'Grr', hint: 'Cuando alguien hace Grr a tus publicaciones o fotografías.' },
  { key: 'comments', label: 'Comentarios', hint: 'Cuando comentan algo tuyo.' },
  { key: 'friendRequests', label: 'Solicitudes de amistad', hint: 'Solicitudes recibidas y aceptadas.' },
  { key: 'events', label: 'Eventos', hint: 'Invitaciones a planes.' },
  { key: 'groups', label: 'Grupos', hint: 'Invitaciones a grupos, solicitudes para entrar en los tuyos y avisos.' },
  { key: 'messages', label: 'Mensajes', hint: 'Mensajes nuevos de tus amigos.' },
  { key: 'tags', label: 'Fotos', hint: 'Cuando te etiquetan o te invitan a compartir una fotografía.' },
]

// METHODS
const toggle = (key, value) => {
  const next = user.draftSettings()
  next.notifications[key] = value
  user.updateSettings(next, 'Preferencias guardadas.')
}
</script>

<template>
  <div class="settings-section">
    <section class="settings-section__block">
      <fieldset class="settings-section__options">
        <legend class="settings-section__title">Avisarme de</legend>
        <label v-for="option in OPTIONS" :key="option.key" class="settings-section__option settings-section__option--switch">
          <span class="settings-section__option-text">
            <span>{{ option.label }}</span>
            <span class="settings-section__option-hint">{{ option.hint }}</span>
          </span>
          <input
            type="checkbox"
            role="switch"
            class="switch"
            :checked="user.settings.notifications[option.key] !== false"
            @change="toggle(option.key, $event.target.checked)"
          />
        </label>
      </fieldset>
    </section>
  </div>
</template>

<style lang="scss" scoped>
@use '@/styles/partials/settings';
</style>
