<script setup>
import { onMounted } from 'vue'
import PersonLink from '@/components/common/PersonLink.vue'
import { useUserStore } from '@/stores/user'
import { useFriendsStore } from '@/stores/friends'

// STORES
const user = useUserStore()
const friends = useFriendsStore()

// DATA
const VISIBILITY = [
  { value: 'everyone', label: 'Cualquier persona en YOUNGrr' },
  { value: 'friends', label: 'Solo mis amigos' },
  { value: 'only_me', label: 'Solo yo' },
]

const QUESTIONS = [
  {
    key: 'profileVisibility',
    title: 'Quién puede ver mi perfil',
    hint: 'Tu nombre y foto de perfil siempre se ven, para que te puedan encontrar.',
    options: VISIBILITY.filter((o) => o.value !== 'only_me'),
  },
  {
    key: 'cityVisibility',
    title: 'Quién puede ver mi ciudad o pueblo',
    hint: 'En tu perfil y en tus publicaciones de «Cerca de ti».',
    options: VISIBILITY,
  },
  {
    key: 'distanceVisibility',
    title: 'Quién puede ver a qué distancia estoy',
    hint: 'Solo aparece en «Cerca de ti» si ocultas tu ciudad o pueblo. Es aproximada, nunca tu ubicación exacta.',
    options: VISIBILITY,
  },
  {
    key: 'friendRequests',
    title: 'Quién puede enviarme solicitudes',
    hint: '',
    options: [
      { value: 'everyone', label: 'Cualquier persona' },
      { value: 'friends_of_friends', label: 'Amigos de mis amigos' },
      { value: 'nobody', label: 'Nadie' },
    ],
  },
]

// METHODS
const update = (key, value) => {
  const next = user.draftSettings()
  next.privacy[key] = value
  user.updateSettings(next, 'Privacidad actualizada.')
}

// LIFECYCLE
onMounted(() => friends.loadBlocked())
</script>

<template>
  <div class="settings-section">
    <section v-for="q in QUESTIONS" :key="q.key" class="settings-section__block">
      <fieldset class="settings-section__options">
        <legend class="settings-section__title">{{ q.title }}</legend>
        <p v-if="q.hint" class="settings-section__option-hint">{{ q.hint }}</p>
        <label v-for="option in q.options" :key="option.value" class="settings-section__option">
          <input
            type="radio"
            :name="q.key"
            :value="option.value"
            :checked="user.settings.privacy[q.key] === option.value"
            @change="update(q.key, option.value)"
          />
          <span>{{ option.label }}</span>
        </label>
      </fieldset>
    </section>

    <section class="settings-section__block" aria-labelledby="privacy-blocked">
      <h2 id="privacy-blocked" class="settings-section__title">Personas bloqueadas</h2>
      <p class="settings-section__option-hint">
        No podéis veros el contenido, escribiros ni enviaros solicitudes. No se les avisa de que las has bloqueado.
      </p>
      <p v-if="!friends.blocked.items.length" class="muted">No has bloqueado a nadie.</p>
      <ul v-else class="blocked" role="list">
        <li v-for="b in friends.blocked.items" :key="b.person.id" class="blocked__item">
          <PersonLink :person="b.person" />
          <button type="button" class="btn btn--ghost btn--sm" @click="friends.unblock(b.person)">Desbloquear</button>
        </li>
      </ul>
    </section>
  </div>
</template>

<style lang="scss" scoped>
@use '@/styles/partials/settings';

.blocked {
  margin: 0;
  padding: 0;

  &__item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: $space-2;
    padding: $space-1 0;
  }
}
</style>
