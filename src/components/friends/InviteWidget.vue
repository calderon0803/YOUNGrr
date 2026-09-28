<script setup>
import { onMounted, ref, useId } from 'vue'
import InvitationLink from '@/components/friends/InvitationLink.vue'
import InvitationsDialog from '@/components/friends/InvitationsDialog.vue'
import { useInvitationsStore } from '@/stores/invitations'
import { errorMessage } from '@/services/errors'
import { rules } from '@/utils/validation'

// Tuenti's "Invitar a tus amigos": YOUNGrr is by invitation only. You write a
// friend's email and get a personal link to send them.

// STORES
const invitations = useInvitationsStore()

// DATA
const titleId = useId()
const inputId = useId()
const email = ref('')
const error = ref('')
const sending = ref(false)
const created = ref(null)
const showAll = ref(false)

// METHODS
const submit = async () => {
  error.value = rules.email(email.value) ?? ''
  if (error.value) return
  sending.value = true
  try {
    created.value = await invitations.invite(email.value)
    email.value = ''
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    sending.value = false
  }
}

// LIFECYCLE
onMounted(() => invitations.load())
</script>

<template>
  <section class="panel invite" :aria-labelledby="titleId">
    <h2 :id="titleId" class="panel-title">Invitar a tus amigos</h2>
    <div v-if="invitations.state.status === 'error'" class="invite__body">
      <p class="invite__available">No se han podido cargar tus invitaciones.</p>
      <button type="button" class="invite__all" @click="invitations.load()">Reintentar</button>
    </div>
    <div v-else-if="invitations.state.status !== 'success'" class="invite__body" aria-busy="true">
      <p class="invite__available">Cargando…</p>
    </div>
    <div v-else class="invite__body">
      <p class="invite__available">
        <strong>{{ invitations.state.available }}</strong>
        {{ invitations.state.available === 1 ? 'invitación disponible' : 'invitaciones disponibles' }}
      </p>

      <form class="invite__form" novalidate @submit.prevent="submit">
        <label class="visually-hidden" :for="inputId">Correo de tu amigo</label>
        <input
          :id="inputId"
          v-model="email"
          class="input invite__input"
          type="email"
          inputmode="email"
          placeholder="Su correo"
          autocomplete="off"
          :aria-invalid="!!error || undefined"
          :disabled="!invitations.state.available && !sending"
        />
        <button type="submit" class="btn btn--primary btn--sm" :disabled="sending || !invitations.state.available">
          {{ sending ? 'Creando…' : 'Invitar' }}
        </button>
      </form>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>

      <div v-if="created?.link" class="invite__created">
        <p class="invite__hint">Envíale este enlace a {{ created.email }}. Solo sirve para ese correo.</p>
        <InvitationLink :link="created.link" :email="created.email" />
      </div>

      <button v-if="invitations.state.items.length" type="button" class="invite__all" @click="showAll = true">
        Ver mis invitaciones ({{ invitations.state.items.length }})
      </button>
    </div>

    <InvitationsDialog :open="showAll" @close="showAll = false" />
  </section>
</template>

<style lang="scss" scoped>
.invite {
  &__body {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    padding: $space-2 $space-3 $space-3;
  }

  &__available {
    font-size: $fs-sm;
    color: $color-text-muted;

    strong {
      color: $color-text;
    }
  }

  &__form {
    display: flex;
    gap: $space-2;
  }

  &__input {
    flex: 1;
    min-width: 0;
    min-height: 2rem;
    font-size: $fs-sm;
  }

  &__created {
    display: flex;
    flex-direction: column;
    gap: $space-1;
  }

  &__hint {
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__all {
    @include reset-button;
    align-self: flex-start;
    font-size: $fs-sm;
    color: $color-link;

    &:hover {
      text-decoration: underline;
    }
  }
}
</style>
