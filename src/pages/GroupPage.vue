<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { CalendarDays, Lock, MessageSquareText, Plus, UserPlus } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import TabNav from '@/components/common/TabNav.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import EventCard from '@/components/events/EventCard.vue'
import EventFormDialog from '@/components/events/EventFormDialog.vue'
import GallineroComposer from '@/components/groups/GallineroComposer.vue'
import GallineroPost from '@/components/groups/GallineroPost.vue'
import GroupMembers from '@/components/groups/GroupMembers.vue'
import GroupFormDialog from '@/components/groups/GroupFormDialog.vue'
import GroupInviteDialog from '@/components/groups/GroupInviteDialog.vue'
import { useGroupsStore } from '@/stores/groups'
import { useEventsStore } from '@/stores/events'
import { useConfirm } from '@/composables/useConfirm'
import { fullDate } from '@/utils/time'
import { groupAvatar, groupKindLabel } from '@/utils/groups'
import { plural } from '@/utils/text'

// A group: what it is, and for its members the Gallinero, its people and its
// events. Everyone else only sees its name, description and size. Place groups
// (communities, provinces, towns) are joined directly.

// STORES
const route = useRoute()
const router = useRouter()
const groups = useGroupsStore()
const events = useEventsStore()
const { confirm } = useConfirm()

// DATA
const editing = ref(false)
const inviting = ref(false)
const creatingEvent = ref(false)

// COMPUTED
const groupId = computed(() => String(route.params.id))
const group = computed(() => groups.groups[groupId.value])
const state = computed(() => groups.details[groupId.value] ?? { status: 'loading', error: null })
const board = computed(() => groups.boards[groupId.value] ?? { status: 'loading', error: null, ids: [], hasMore: false })
const groupEvents = computed(() => events.groupLists[groupId.value] ?? { status: 'loading', error: null, upcoming: [], past: [] })
const isMember = computed(() => !!group.value?.myRole)
const isAdmin = computed(() => !!group.value?.canManage)
const isPlace = computed(() => group.value?.kind === 'place')
const tab = computed(() => (['people', 'events'].includes(route.query.tab) ? route.query.tab : 'gallinero'))
const tabs = computed(() => [
  { key: 'gallinero', label: 'Gallinero' },
  { key: 'people', label: 'Personas', count: isAdmin.value ? (groups.details[groupId.value]?.requests.length ?? 0) : 0 },
  { key: 'events', label: 'Eventos' },
])
const menu = computed(() => [
  ...(isAdmin.value ? [{ key: 'edit', label: 'Editar grupo' }] : []),
  { key: 'leave', label: 'Salir del grupo', danger: true },
  ...(group.value?.myRole === 'owner' ? [{ key: 'delete', label: 'Eliminar grupo', danger: true }] : []),
])
const eventSections = computed(() =>
  [
    { key: 'upcoming', title: 'Próximos', items: groupEvents.value.upcoming.map((id) => events.events[id]).filter(Boolean) },
    { key: 'past', title: 'Anteriores', items: groupEvents.value.past.map((id) => events.events[id]).filter(Boolean) },
  ].filter((s) => s.items.length),
)

// METHODS
const tabRoute = (key) => ({ query: key === 'gallinero' ? {} : { tab: key } })

const onMenu = async (key) => {
  if (key === 'edit') editing.value = true
  else if (key === 'leave') {
    const owner = group.value.myRole === 'owner'
    const place = isPlace.value
    const ok = await confirm({
      title: 'Salir del grupo',
      message: owner
        ? 'Dejarás de ver el Gallinero y sus eventos. Pasará a ser propietario quien más tiempo lleve administrando (o, si no hay nadie, quien más tiempo lleve en el grupo).'
        : place
          ? 'Dejarás de ver el Gallinero y sus eventos. Puedes volver a unirte cuando quieras.'
          : 'Dejarás de ver el Gallinero y sus eventos. Para volver tendrán que invitarte o aceptar tu solicitud.',
      confirmLabel: 'Salir',
      danger: true,
    })
    if (ok && (await groups.leave(groupId.value))) router.push({ name: 'groups' })
  } else if (key === 'delete') {
    const ok = await confirm({
      title: 'Eliminar grupo',
      message: 'Se borrarán el Gallinero, sus eventos y la lista de personas para todo el mundo. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    })
    if (ok) {
      await groups.deleteGroup(groupId.value)
      router.push({ name: 'groups' })
    }
  }
}

const answer = async (accept) => {
  if (!(await groups.answerInvite(groupId.value, accept)) && !accept) router.push({ name: 'groups' })
}

const loadInside = () => {
  if (!isMember.value) return
  if (tab.value === 'gallinero') {
    groups.loadPosts(groupId.value).then(() => groups.markSeen(groupId.value))
  } else if (tab.value === 'events') {
    events.loadGroupEvents(groupId.value)
  }
}

// WATCHERS
watch(groupId, (id) => groups.loadGroup(id), { immediate: true })
watch([groupId, tab, isMember], loadInside, { immediate: true })
</script>

<template>
  <div class="group-page">
    <AsyncState :status="state.status" :error="state.error" skeleton="block" :skeleton-count="1" @retry="groups.loadGroup(groupId)">
      <template v-if="group">
        <section class="panel group-page__head" aria-labelledby="group-title">
          <UserAvatar :person="groupAvatar(group)" size="lg" />
          <div class="group-page__info">
            <h1 id="group-title" class="group-page__name">{{ group.name }}</h1>
            <p class="group-page__meta">
              <Lock v-if="group.privacy === 'secret'" aria-hidden="true" />
              {{ groupKindLabel(group) }} · {{ plural(group.memberCount, 'persona', 'personas') }}
              <template v-if="group.parent">
                · <RouterLink :to="{ name: 'group', params: { id: group.parent.id } }">{{ group.parent.name }}</RouterLink>
              </template>
            </p>
            <p v-if="group.description" class="group-page__description user-text">{{ group.description }}</p>
            <p v-if="group.expiresAt" class="group-page__warning">
              Si nadie se une antes del {{ fullDate(group.expiresAt) }}, el grupo se eliminará. Invita a tus amigos.
            </p>

            <div class="group-page__actions">
              <template v-if="isMember">
                <button type="button" class="btn btn--primary btn--sm" @click="inviting = true">
                  <UserPlus aria-hidden="true" />
                  Invitar amigos
                </button>
              </template>
              <template v-else-if="group.invitedBy">
                <span class="group-page__invited">Te invita {{ group.invitedBy.firstName }}</span>
                <button type="button" class="btn btn--primary btn--sm" @click="answer(true)">Unirme</button>
                <button type="button" class="btn btn--secondary btn--sm" @click="answer(false)">Rechazar</button>
              </template>
              <button v-else-if="group.requested" type="button" class="btn btn--secondary btn--sm" @click="groups.cancelRequest(groupId)">Retirar solicitud</button>
              <button v-else-if="isPlace" type="button" class="btn btn--primary btn--sm" @click="groups.requestToJoin(groupId)">Unirme</button>
              <button v-else-if="group.privacy === 'closed'" type="button" class="btn btn--primary btn--sm" @click="groups.requestToJoin(groupId)">Pedir entrar</button>
            </div>
          </div>
          <DropdownMenu v-if="isMember" class="group-page__menu" label="Opciones del grupo" :items="menu" @select="onMenu" />
        </section>

        <section v-if="isMember" class="panel group-page__content">
          <TabNav label="Secciones del grupo" :tabs="tabs" :active="tab" :to="tabRoute" />

          <template v-if="tab === 'gallinero'">
            <GallineroComposer :group-id="groupId" />
            <AsyncState :status="board.status" :error="board.error" :empty="!board.ids.length" skeleton="post" @retry="groups.loadPosts(groupId)">
              <template #empty>
                <StateMessage :icon="MessageSquareText" title="El Gallinero está en silencio." text="Escribe lo primero: un plan, una pregunta, una foto…" />
              </template>
              <GallineroPost v-for="id in board.ids" :key="id" :post-id="id" />
              <button v-if="board.hasMore" type="button" class="btn btn--ghost btn--block group-page__more" :disabled="board.loadingMore" @click="groups.loadPosts(groupId, { more: true })">
                {{ board.loadingMore ? 'Cargando…' : 'Ver más' }}
              </button>
            </AsyncState>
          </template>

          <GroupMembers v-else-if="tab === 'people'" :group-id="groupId" />

          <div v-else class="group-page__events">
            <button type="button" class="btn btn--primary btn--sm" @click="creatingEvent = true">
              <Plus aria-hidden="true" />
              Crear evento del grupo
            </button>
            <AsyncState
              :status="groupEvents.status"
              :error="groupEvents.error"
              :empty="!eventSections.length"
              skeleton="block"
              :skeleton-count="1"
              @retry="events.loadGroupEvents(groupId)"
            >
              <template #empty>
                <StateMessage :icon="CalendarDays" compact title="El grupo no tiene planes." text="Crea uno: lo verán todas las personas del grupo y podrán apuntarse." />
              </template>
              <section v-for="section in eventSections" :key="section.key" :aria-labelledby="`group-events-${section.key}`">
                <h2 :id="`group-events-${section.key}`" class="group-page__subtitle">{{ section.title }}</h2>
                <ul class="group-page__grid" role="list">
                  <EventCard v-for="event in section.items" :key="event.id" :event="event" />
                </ul>
              </section>
            </AsyncState>
          </div>
        </section>

        <div v-else class="panel">
          <StateMessage
            :icon="Lock"
            title="Solo las personas del grupo ven lo que hay dentro."
            :text="
              isPlace
                ? 'Únete para ver su Gallinero y sus eventos. De la gente que está dentro solo verás a tus amigos.'
                : group.privacy === 'closed'
                  ? 'Pide entrar y quien lo administra te dará paso.'
                  : 'A este grupo solo se entra con invitación.'
            "
          />
        </div>

        <GroupFormDialog v-if="isAdmin" :open="editing" :group="group" @close="editing = false" />
        <GroupInviteDialog v-if="isMember" :open="inviting" :group-id="groupId" @close="inviting = false" />
        <EventFormDialog
          v-if="isMember"
          :open="creatingEvent"
          :group="{ id: group.id, name: group.name }"
          @close="creatingEvent = false"
          @saved="(event) => router.push({ name: 'event', params: { id: event.id } })"
        />
      </template>
    </AsyncState>
  </div>
</template>

<style lang="scss" scoped>
.group-page {
  display: flex;
  flex-direction: column;
  gap: $space-4;
  max-width: 44rem;

  &__head {
    display: flex;
    align-items: flex-start;
    gap: $space-3;
    padding: $space-4;
    border-radius: 0;
    border-right: 0;
    border-left: 0;
  }

  &__info {
    display: flex;
    flex: 1;
    flex-direction: column;
    gap: $space-1;
    min-width: 0;
  }

  &__name {
    font-family: $font-display;
    font-size: $fs-xl;
    overflow-wrap: anywhere;
  }

  &__meta {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    font-size: $fs-sm;
    color: $color-text-muted;

    svg {
      width: 0.9rem;
      height: 0.9rem;
    }
  }

  &__description {
    overflow-wrap: anywhere;
  }

  &__warning {
    padding: $space-2 $space-3;
    border-radius: $radius-sm;
    background: $color-brand-tint;
    font-size: $fs-sm;
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: $space-2;
    margin-top: $space-2;
  }

  &__invited {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__menu {
    flex-shrink: 0;
  }

  &__content {
    overflow: hidden;
    border-radius: 0;
    border-right: 0;
    border-left: 0;
  }

  &__more {
    border-top: 1px solid $color-border;
    border-radius: 0;
  }

  &__events {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: $space-3;
    padding: $space-3;

    > :last-child {
      align-self: stretch;
    }
  }

  &__subtitle {
    @include section-title;
    margin-bottom: $space-2;
  }

  &__grid {
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    gap: $space-3;
    margin: 0 0 $space-3;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .group-page {
    margin: 0 auto;

    &__head,
    &__content {
      border-right: 1px solid $color-border;
      border-left: 1px solid $color-border;
      border-radius: $radius;
    }

    &__grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }
}
</style>
