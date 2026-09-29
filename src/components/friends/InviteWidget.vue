<script setup>
import { onMounted, ref, useId } from 'vue'
import { Link } from 'lucide-vue-next'
import InvitationLink from '@/components/friends/InvitationLink.vue'
import InvitationsDialog from '@/components/friends/InvitationsDialog.vue'
import { useInvitationsStore } from '@/stores/invitations'
import { errorMessage } from '@/services/errors'
import { shortDayMonth, toDateInput } from '@/utils/time'
import { INVITATION_DAYS } from '@/config/app'

// Tuenti's "Invitar a tus amigos": YOUNGrr is by invitation only. One click
// gives a single-use link to send to a friend.

// STORES
const invitations = useInvitationsStore()

// DATA
const titleId = useId()
const error = ref('')
const sending = ref(false)
const created = ref(null)
const showAll = ref(false)

// METHODS
const create = async () => {
  error.value = ''
  sending.value = true
  try {
    created.value = await invitations.invite()
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
        <template v-if="invitations.state.nextAt">· otra el {{ shortDayMonth(toDateInput(new Date(invitations.state.nextAt))) }}</template>
      </p>

      <button type="button" class="btn btn--primary btn--sm btn--block" :disabled="sending || !invitations.state.available" @click="create">
        <Link aria-hidden="true" />
        {{ sending ? 'Creando…' : 'Crear enlace de invitación' }}
      </button>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>

      <div v-if="created?.link" class="invite__created">
        <p class="invite__hint">Envíaselo a tu amigo. Sirve para una sola cuenta y caduca en {{ INVITATION_DAYS }} días.</p>
        <InvitationLink :link="created.link" />
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
