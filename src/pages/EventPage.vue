<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Clock, MapPin, UserPlus } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import EventDateBadge from '@/components/events/EventDateBadge.vue'
import RsvpControl from '@/components/events/RsvpControl.vue'
import AttendeeList from '@/components/events/AttendeeList.vue'
import EventFormDialog from '@/components/events/EventFormDialog.vue'
import InviteDialog from '@/components/events/InviteDialog.vue'
import { useEventsStore } from '@/stores/events'
import { useConfirm } from '@/composables/useConfirm'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { formatEventDate, isPastEvent } from '@/utils/time'
import { plural } from '@/utils/text'

// STORES
const route = useRoute()
const router = useRouter()
const events = useEventsStore()
const { confirm } = useConfirm()
const toast = useToast()

// DATA
const editing = ref(false)
const inviting = ref(false)
const MENU = [
  { key: 'edit', label: 'Editar evento' },
  { key: 'delete', label: 'Eliminar evento', danger: true },
]

// COMPUTED
const eventId = computed(() => String(route.params.id))
const state = computed(() => events.details[eventId.value] ?? { status: 'loading', error: null })
const event = computed(() => events.events[eventId.value])
const past = computed(() => event.value && isPastEvent(event.value.date, event.value.time))
const canInvite = computed(() => event.value && !past.value && (event.value.isCreator || ['going', 'maybe'].includes(event.value.myStatus)))

// METHODS
const onMenu = async (key) => {
  if (key === 'edit') {
    editing.value = true
    return
  }
  const ok = await confirm({ title: 'Eliminar evento', message: 'Los invitados dejarán de verlo.', confirmLabel: 'Eliminar', danger: true })
  if (!ok) return
  try {
    await events.deleteEvent(eventId.value)
    router.replace({ name: 'events' })
  } catch (error) {
    toast.error(errorMessage(error))
  }
}

// WATCHERS
watch(eventId, (id) => events.loadEvent(id), { immediate: true })
</script>

<template>
  <div class="event-page">
    <RouterLink class="event-page__back" :to="{ name: 'events' }">
      <ArrowLeft aria-hidden="true" />
      Eventos
    </RouterLink>

    <AsyncState :status="state.status" :error="state.error" skeleton="block" @retry="events.loadEvent(eventId)">
      <article v-if="event" class="event panel">
        <div class="event__image">
          <img v-if="event.imageUrl" :src="event.imageUrl" alt="" />
        </div>

        <header class="event__header">
          <EventDateBadge :date="event.date" large />
          <div class="event__heading">
            <h1 class="event__title">{{ event.title }}</h1>
            <p class="event__creator">
              <UserAvatar :person="event.creator" size="xs" />
              <span>Organiza <PersonLink :person="event.creator" /></span>
              <span v-if="event.isPublic" class="event__public">Público</span>
            </p>
          </div>
          <DropdownMenu v-if="event.isCreator" label="Opciones del evento" :items="MENU" @select="onMenu" />
        </header>

        <dl class="event__facts">
          <div class="event__fact">
            <dt><Clock aria-hidden="true" /><span class="visually-hidden">Fecha y hora</span></dt>
            <dd>{{ formatEventDate(event.date, event.time) }}<span v-if="past" class="event__past"> · Ya pasó</span></dd>
          </div>
          <div class="event__fact">
            <dt><MapPin aria-hidden="true" /><span class="visually-hidden">Ubicación</span></dt>
            <dd>{{ event.location }}</dd>
          </div>
        </dl>

        <!-- Invited people answer; in a public event anyone who sees it joins by answering. -->
        <div v-if="!event.isCreator && (event.myStatus || event.isPublic) && !past" class="event__rsvp">
          <RsvpControl :event="event" />
        </div>

        <p v-if="event.description" class="event__description user-text">{{ event.description }}</p>

        <section class="event__people" aria-labelledby="event-people-title">
          <div class="event__people-head">
            <h2 id="event-people-title" class="event__people-title">
              {{ plural(event.counts.going, 'asistente', 'asistentes') }}
              <span class="muted">· {{ plural(event.members.length, 'invitado', 'invitados') }}</span>
            </h2>
            <button v-if="canInvite" type="button" class="btn btn--soft btn--sm" @click="inviting = true">
              <UserPlus aria-hidden="true" />
              Invitar
            </button>
          </div>
          <AttendeeList :members="event.members" />
        </section>

        <EventFormDialog v-if="event.isCreator" :open="editing" :event="event" @close="editing = false" />
        <InviteDialog v-if="canInvite" :open="inviting" :event="event" @close="inviting = false" />
      </article>
    </AsyncState>
  </div>
</template>

<style lang="scss" scoped>
.event-page {
  display: flex;
  flex-direction: column;
  gap: $space-3;
  max-width: 50rem;

  &__back {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    padding: 0 $space-3;
    font-weight: 600;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }
}

.event {
  &__public {
    padding: 0.05rem $space-2;
    border-radius: $radius-sm;
    background: $color-brand-tint;
    color: $color-brand-strong;
    font-size: $fs-xs;
    font-weight: 700;
  }

  overflow: hidden;

  &__image {
    aspect-ratio: 2.6;
    background: $color-brand-soft;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__header {
    display: flex;
    align-items: flex-start;
    gap: $space-3;
    padding: $space-4;
  }

  &__heading {
    flex: 1;
    min-width: 0;
  }

  &__title {
    font-size: $fs-xl;
    font-weight: 800;
  }

  &__creator {
    display: flex;
    align-items: center;
    gap: $space-2;
    margin-top: $space-1;
    color: $color-text-muted;
  }

  &__facts {
    display: grid;
    gap: $space-2;
    margin: 0;
    padding: 0 $space-4 $space-4;
  }

  &__fact {
    display: flex;
    gap: $space-2;

    dt svg {
      width: 1.1rem;
      height: 1.1rem;
      margin-top: 0.15rem;
      color: $color-text-muted;
    }

    dd {
      margin: 0;
      font-weight: 600;
    }
  }

  &__past {
    color: $color-text-muted;
    font-weight: 400;
  }

  &__rsvp {
    padding: $space-4;
    background: $color-surface-alt;
    border-top: 1px solid $color-border;
    border-bottom: 1px solid $color-border;
  }

  &__description {
    padding: $space-4;
    font-size: $fs-md;
  }

  &__people {
    padding: $space-4;
    border-top: 1px solid $color-border;
  }

  &__people-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: $space-3;
    margin-bottom: $space-4;
  }

  &__people-title {
    font-size: $fs-md;
    font-weight: 700;
  }
}
</style>
