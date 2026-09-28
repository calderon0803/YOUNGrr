<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Search } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PersonGrid from '@/components/friends/PersonGrid.vue'
import AlbumGrid from '@/components/photos/AlbumGrid.vue'
import EventCard from '@/components/events/EventCard.vue'
import { useSearchStore } from '@/stores/search'
import { debounce } from '@/utils/debounce'
import { SEARCH_DEBOUNCE_MS } from '@/config/app'

// STORES
const route = useRoute()
const router = useRouter()
const search = useSearchStore()

// DATA
const query = ref(typeof route.query.q === 'string' ? route.query.q : '')
const syncUrl = debounce((q) => router.replace({ query: q.trim() ? { q: q.trim() } : {} }), SEARCH_DEBOUNCE_MS)

// COMPUTED
const results = computed(() => search.state)
const total = computed(() => results.value.people.length + results.value.events.length + results.value.albums.length)

// LIFECYCLE
onBeforeUnmount(() => syncUrl.cancel())

// WATCHERS
watch(query, (q) => syncUrl(q))
watch(
  () => route.query.q,
  (q) => {
    const value = typeof q === 'string' ? q : ''
    if (value !== query.value.trim()) query.value = value
    search.search(value)
  },
  { immediate: true },
)
</script>

<template>
  <div class="search-page">
    <h1 class="page-title search-page__title">Buscar</h1>
    <form class="search-page__form" role="search" @submit.prevent="search.search(query)">
      <label class="visually-hidden" for="global-search">Buscar personas, eventos y álbumes</label>
      <Search class="search-page__icon" aria-hidden="true" />
      <input id="global-search" v-model="query" class="input search-page__input" type="search" placeholder="Personas, eventos, álbumes" autocomplete="off" autofocus enterkeyhint="search" />
    </form>

    <div v-if="!query.trim()" class="panel">
      <StateMessage :icon="Search" title="¿A quién buscas?" text="Encuentra personas por su nombre o ciudad, eventos a los que te han invitado y álbumes de tus amigos." />
    </div>

    <AsyncState v-else :status="results.status" :error="results.error" :empty="total === 0" @retry="search.search(query)">
      <template #empty>
        <div class="panel">
          <StateMessage :title="`Sin resultados para «${query.trim()}».`" text="Revisa cómo está escrito o prueba con otra palabra." />
        </div>
      </template>

      <section v-if="results.people.length" class="panel search-page__group" aria-labelledby="res-people">
        <h2 id="res-people" class="panel-title">Personas <span class="search-page__count">{{ results.people.length }}</span></h2>
        <PersonGrid :people="results.people" label="Personas encontradas" />
      </section>

      <section v-if="results.events.length" class="search-page__group" aria-labelledby="res-events">
        <h2 id="res-events" class="search-page__heading">Eventos <span class="search-page__count">{{ results.events.length }}</span></h2>
        <ul class="search-page__events" role="list">
          <EventCard v-for="event in results.events" :key="event.id" :event="event" />
        </ul>
      </section>

      <section v-if="results.albums.length" class="panel search-page__group" aria-labelledby="res-albums">
        <h2 id="res-albums" class="panel-title">Álbumes <span class="search-page__count">{{ results.albums.length }}</span></h2>
        <AlbumGrid :albums="results.albums" label="Álbumes encontrados" show-owner />
      </section>
    </AsyncState>
  </div>
</template>

<style lang="scss" scoped>
.search-page {
  display: flex;
  flex-direction: column;
  gap: $space-3;
  padding: 0 $space-3;

  &__title {
    margin-bottom: 0;
  }

  &__form {
    position: relative;
  }

  &__icon {
    position: absolute;
    top: 50%;
    left: $space-3;
    width: 1.1rem;
    height: 1.1rem;
    color: $color-text-soft;
    transform: translateY(-50%);
  }

  &__input {
    min-height: 2.75rem;
    padding-left: 2.5rem;
    font-size: $fs-md;
  }

  &__heading {
    @include section-title;
    margin-bottom: $space-2;
  }

  &__count {
    color: $color-text-soft;
  }

  &__events {
    display: grid;
    gap: $space-3;
    margin: 0;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .search-page {
    padding: 0;

    &__events {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }
}
</style>
