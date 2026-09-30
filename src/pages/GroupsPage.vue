<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { MapPin, Plus, Search, UsersRound, X } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import GroupListItem from '@/components/groups/GroupListItem.vue'
import GroupFormDialog from '@/components/groups/GroupFormDialog.vue'
import PlaceRequestDialog from '@/components/groups/PlaceRequestDialog.vue'
import PlaceTree from '@/components/groups/PlaceTree.vue'
import { useGroupsStore } from '@/stores/groups'
import { useNotificationsStore } from '@/stores/notifications'
import { useAuthStore } from '@/stores/auth'
import { debounce } from '@/utils/debounce'
import { fullDate } from '@/utils/time'
import { GROUPS, SEARCH_DEBOUNCE_MS } from '@/config/app'

// Groups: notices, invitations, your groups, a search of closed groups and the
// groups of places (your area, your requests and all of them by community).

// STORES
const groups = useGroupsStore()
const notifications = useNotificationsStore()
const auth = useAuthStore()
const router = useRouter()

// DATA
const creating = ref(false)
const askingPlace = ref(false)
const query = ref('')

// COMPUTED
const pick = (ids) => ids.map((id) => groups.groups[id]).filter(Boolean)
const mine = computed(() => pick(groups.mine.ids))
const invited = computed(() => pick(groups.invitations.ids))
const results = computed(() => pick(groups.found.ids))
const suggested = computed(() => pick(groups.suggested.ids))
const myCity = computed(() => auth.me?.city ?? '')
// Your town has no group yet: it can be asked for.
const townMissing = computed(() => !!myCity.value && groups.suggested.status === 'success' && !suggested.value.some((g) => g.placeLevel === 'municipality'))

// METHODS
const onCreated = (group) => router.push({ name: 'group', params: { id: group.id } })
const runSearch = debounce((value) => groups.search(value), SEARCH_DEBOUNCE_MS)

const answer = async (group, accept) => {
  if ((await groups.answerInvite(group.id, accept)) && accept) router.push({ name: 'group', params: { id: group.id } })
}

// LIFECYCLE
onMounted(() => {
  groups.loadMine()
  groups.loadInvitations()
  groups.loadNotices()
  groups.loadSuggested()
  groups.loadPlaceRequests()
})

// WATCHERS
watch(query, (value) => runSearch(value))
watch(
  () => groups.notices.items.length,
  () => notifications.loadSummary(),
)
</script>

<template>
  <div class="groups-page">
    <div class="groups-page__head">
      <h1 class="page-title">Grupos</h1>
      <button type="button" class="btn btn--primary" @click="creating = true">
        <Plus aria-hidden="true" />
        Crear grupo
      </button>
    </div>

    <ul v-if="groups.notices.items.length" class="groups-page__notices" role="list">
      <li v-for="notice in groups.notices.items" :key="notice.id" class="groups-page__notice" role="status">
        <p v-if="notice.kind === 'activated'">
          Ya existe el grupo de
          <RouterLink :to="{ name: 'group', params: { id: notice.groupId } }"><strong>{{ notice.groupName }}</strong></RouterLink>
          que pediste, y ya estás dentro.
        </p>
        <p v-else>
          Tu grupo <strong>«{{ notice.groupName }}»</strong> se ha eliminado porque nadie se unió en {{ GROUPS.emptyDays }} días.
        </p>
        <button type="button" class="groups-page__close" aria-label="Cerrar el aviso" @click="groups.dismissNotice(notice.id)">
          <X aria-hidden="true" />
        </button>
      </li>
    </ul>

    <section v-if="invited.length" class="panel" aria-labelledby="groups-invited-title">
      <h2 id="groups-invited-title" class="panel-title">Te han invitado</h2>
      <ul class="groups-page__list" role="list">
        <GroupListItem v-for="group in invited" :key="group.id" :group="group">
          <button type="button" class="btn btn--primary btn--sm" @click="answer(group, true)">Unirme</button>
          <button type="button" class="btn btn--secondary btn--sm" @click="answer(group, false)">Rechazar</button>
        </GroupListItem>
      </ul>
    </section>

    <section class="panel" aria-labelledby="groups-mine-title">
      <h2 id="groups-mine-title" class="panel-title">Tus grupos</h2>
      <AsyncState :status="groups.mine.status" :error="groups.mine.error" :empty="!mine.length" @retry="groups.loadMine()">
        <template #empty>
          <StateMessage :icon="UsersRound" title="Todavía no estás en ningún grupo." text="Crea uno e invita a tus amigos, o busca un grupo cerrado y pide entrar.">
            <button type="button" class="btn btn--primary" @click="creating = true">Crear grupo</button>
          </StateMessage>
        </template>
        <ul class="groups-page__list" role="list">
          <GroupListItem v-for="group in mine" :key="group.id" :group="group" show-new />
        </ul>
      </AsyncState>
    </section>

    <section class="panel" aria-labelledby="groups-search-title">
      <h2 id="groups-search-title" class="panel-title">Buscar grupos</h2>
      <div class="groups-page__search">
        <div class="groups-page__search-box">
          <Search class="groups-page__search-icon" aria-hidden="true" />
          <label class="visually-hidden" for="groups-search">Buscar grupos por su nombre</label>
          <input id="groups-search" v-model="query" class="input" type="search" placeholder="Nombre del grupo" autocomplete="off" enterkeyhint="search" />
        </div>
      </div>
      <p v-if="groups.found.status === 'idle'" class="groups-page__hint">Los grupos secretos no aparecen: a ellos solo se entra con invitación.</p>
      <AsyncState
        v-else
        :status="groups.found.status"
        :error="groups.found.error"
        :empty="!results.length"
        :skeleton-count="2"
        @retry="groups.search(query)"
      >
        <template #empty>
          <StateMessage compact title="No hay grupos con ese nombre." text="Prueba con otra palabra o crea el grupo tú." />
        </template>
        <ul class="groups-page__list" role="list">
          <GroupListItem v-for="group in results" :key="group.id" :group="group">
            <RouterLink v-if="group.myRole" class="btn btn--secondary btn--sm" :to="{ name: 'group', params: { id: group.id } }">Entrar</RouterLink>
            <button v-else-if="group.requested" type="button" class="btn btn--secondary btn--sm" @click="groups.cancelRequest(group.id)">Retirar solicitud</button>
            <button v-else type="button" class="btn btn--primary btn--sm" @click="groups.requestToJoin(group.id)">
              {{ group.invitedBy || group.kind === 'place' ? 'Unirme' : 'Pedir entrar' }}
            </button>
          </GroupListItem>
        </ul>
      </AsyncState>
    </section>

    <section class="panel" aria-labelledby="groups-places-title">
      <h2 id="groups-places-title" class="panel-title">Grupos de lugares</h2>
      <div class="groups-page__places">
        <section v-if="suggested.length || townMissing" aria-labelledby="groups-area-title">
          <h3 id="groups-area-title" class="groups-page__subtitle">Tu zona</h3>
          <ul v-if="suggested.length" class="groups-page__list" role="list">
            <GroupListItem v-for="group in suggested" :key="group.id" :group="group">
              <RouterLink v-if="group.myRole" class="btn btn--secondary btn--sm" :to="{ name: 'group', params: { id: group.id } }">Entrar</RouterLink>
              <button v-else type="button" class="btn btn--primary btn--sm" @click="groups.requestToJoin(group.id)">Unirme</button>
            </GroupListItem>
          </ul>
          <p v-if="townMissing" class="groups-page__hint groups-page__hint--flush">
            Todavía no hay grupo de {{ myCity }}.
            <button type="button" class="groups-page__link" @click="askingPlace = true">Pídelo</button>
          </p>
        </section>

        <section v-if="groups.placeRequests.items.length" aria-labelledby="groups-requests-title">
          <h3 id="groups-requests-title" class="groups-page__subtitle">Tus peticiones</h3>
          <ul class="groups-page__requests" role="list">
            <li v-for="request in groups.placeRequests.items" :key="request.key" class="groups-page__request">
              <MapPin aria-hidden="true" />
              <span class="groups-page__request-text">
                <strong>{{ request.name }}</strong>
                <span>{{ request.count }} de {{ request.threshold }} personas · caduca el {{ fullDate(request.expiresAt) }}</span>
              </span>
              <button type="button" class="btn btn--ghost btn--sm" @click="groups.cancelPlaceRequest(request.key)">Retirar</button>
            </li>
          </ul>
        </section>

        <section aria-labelledby="groups-all-places-title">
          <div class="groups-page__places-head">
            <h3 id="groups-all-places-title" class="groups-page__subtitle">Por comunidades</h3>
            <button type="button" class="btn btn--secondary btn--sm" @click="askingPlace = true">
              <MapPin aria-hidden="true" />
              Pedir el grupo de un pueblo
            </button>
          </div>
          <PlaceTree />
        </section>
      </div>
    </section>

    <GroupFormDialog :open="creating" @close="creating = false" @saved="onCreated" />
    <PlaceRequestDialog :open="askingPlace" :initial="townMissing ? { name: myCity } : null" @close="askingPlace = false" />
  </div>
</template>

<style lang="scss" scoped>
.groups-page {
  display: flex;
  flex-direction: column;
  gap: $space-4;
  max-width: 44rem;
  padding: 0 $space-3;

  &__head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: $space-3;
  }

  &__notices {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    margin: 0;
    padding: 0;
  }

  &__notice {
    display: flex;
    align-items: flex-start;
    gap: $space-2;
    padding: $space-3;
    border: 1px solid $color-border;
    border-radius: $radius;
    background: $color-surface-alt;
    font-size: $fs-sm;

    p {
      flex: 1;
    }
  }

  &__close {
    @include reset-button;
    display: grid;
    place-items: center;
    width: 1.75rem;
    height: 1.75rem;
    border-radius: $radius-sm;
    color: $color-text-muted;

    svg {
      width: 1rem;
      height: 1rem;
    }

    &:hover {
      background: $color-surface-hover;
    }
  }

  &__list {
    margin: 0;
    padding: 0;
  }

  &__search {
    padding: $space-3 $space-3 0;
  }

  &__search-box {
    position: relative;

    .input {
      padding-left: 2rem;
    }
  }

  &__search-icon {
    position: absolute;
    top: 50%;
    left: $space-2;
    width: 1rem;
    height: 1rem;
    color: $color-text-soft;
    transform: translateY(-50%);
  }

  &__hint {
    padding: $space-2 $space-3 $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;

    &--flush {
      padding: $space-2 0 0;
    }
  }

  &__link {
    @include reset-button;
    color: $color-link;
    font-weight: 600;

    &:hover {
      text-decoration: underline;
    }
  }

  &__places {
    display: flex;
    flex-direction: column;
    gap: $space-4;
    padding: $space-3;

    .groups-page__list {
      margin: 0 (-$space-3);
    }
  }

  &__places-head {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: $space-2;
    margin-bottom: $space-2;

    .groups-page__subtitle {
      margin-bottom: 0;
    }
  }

  &__subtitle {
    @include section-title;
    margin-bottom: $space-2;
  }

  &__requests {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    margin: 0;
    padding: 0;
  }

  &__request {
    display: flex;
    align-items: center;
    gap: $space-2;

    > svg {
      flex-shrink: 0;
      width: 1rem;
      height: 1rem;
      color: $color-text-soft;
    }
  }

  &__request-text {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
    font-size: $fs-sm;

    span {
      color: $color-text-muted;
    }
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .groups-page {
    margin: 0 auto;
    padding: 0;
  }
}
</style>
