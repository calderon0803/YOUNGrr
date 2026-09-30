<script setup>
import { onMounted } from 'vue'
import PersonLink from '@/components/common/PersonLink.vue'
import { useUserStore } from '@/stores/user'
import { useFriendsStore } from '@/stores/friends'
import { GROUP_NOTIFY_OPTIONS, GROUP_SHARE_OPTIONS } from '@/utils/groups'

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
    hint: 'En tu perfil y en las listas de personas.',
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

// Groups: separate from friends; the defaults for each group you join.
const GROUP_QUESTIONS = [
  {
    key: 'profileShare',
    title: 'Qué ve de mí la gente de mis grupos que no es mi amiga',
    hint: 'Valor para los grupos en los que entres. Lo cambias en cada grupo desde su menú. Tus amigos siempre siguen lo de arriba.',
    options: GROUP_SHARE_OPTIONS,
  },
  {
    key: 'notify',
    title: 'Avisos de mis grupos',
    hint: 'Valor para los grupos en los que entres. Los grupos de lugares solo avisan cuando te mencionan.',
    options: GROUP_NOTIFY_OPTIONS,
  },
  {
    key: 'invites',
    title: 'Quién puede invitarme a grupos',
    hint: 'Las invitaciones siempre las aceptas tú.',
    options: [
      { value: 'friends', label: 'Mis amigos' },
      { value: 'nobody', label: 'Nadie' },
    ],
  },
]

// METHODS
const updateGroups = (key, value) => {
  const next = user.draftSettings()
  next.groups = { ...next.groups, [key]: value }
  user.updateSettings(next, 'Privacidad actualizada.')
}

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

    <h2 class="settings-section__heading">Grupos</h2>
    <section v-for="q in GROUP_QUESTIONS" :key="q.key" class="settings-section__block">
      <fieldset class="settings-section__options">
        <legend class="settings-section__title">{{ q.title }}</legend>
        <p class="settings-section__option-hint">{{ q.hint }}</p>
        <label v-for="option in q.options" :key="option.value" class="settings-section__option">
          <input
            type="radio"
            :name="`groups-${q.key}`"
            :value="option.value"
            :checked="(user.settings.groups?.[q.key] ?? q.options[0].value) === option.value"
            @change="updateGroups(q.key, option.value)"
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
