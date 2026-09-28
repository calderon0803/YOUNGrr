<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { Search } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PersonGrid from '@/components/friends/PersonGrid.vue'
import { useFriendsStore } from '@/stores/friends'
import { debounce } from '@/utils/debounce'
import { SEARCH_DEBOUNCE_MS } from '@/config/app'

// STORES
const friends = useFriendsStore()

// DATA
const query = ref(friends.people.query)
const search = debounce((q) => friends.searchPeople(q), SEARCH_DEBOUNCE_MS)

// LIFECYCLE
onMounted(() => friends.loadSuggestions())
onBeforeUnmount(() => search.cancel())

// WATCHERS
watch(query, (q) => search(q))
</script>

<template>
  <div class="people-search">
    <form class="people-search__form" role="search" @submit.prevent="friends.searchPeople(query)">
      <label class="visually-hidden" for="people-query">Buscar personas por nombre o ciudad</label>
      <Search class="people-search__icon" aria-hidden="true" />
      <input id="people-query" v-model="query" class="input people-search__input" type="search" placeholder="Nombre, apellido o ciudad" autocomplete="off" autofocus />
    </form>

    <template v-if="query.trim()">
      <AsyncState :status="friends.people.status" :error="friends.people.error" :empty="!friends.people.items.length" @retry="friends.searchPeople(query)">
        <template #empty>
          <StateMessage compact :title="`No hay nadie llamado «${query.trim()}».`" text="Prueba con su apellido o su ciudad." />
        </template>
        <PersonGrid :people="friends.people.items" label="Resultados" />
      </AsyncState>
    </template>

    <section v-else-if="friends.suggestions.items.length" aria-labelledby="people-suggestions">
      <h2 id="people-suggestions" class="panel-title">Amigos de tus amigos</h2>
      <PersonGrid :people="friends.suggestions.items" label="Sugerencias" />
    </section>
    <StateMessage v-else compact :icon="Search" title="Busca a tus amigos por su nombre." />
  </div>
</template>

<style lang="scss" scoped>
.people-search {
  &__form {
    position: relative;
    padding: $space-3 $space-4;
    border-bottom: 1px solid $color-border;
  }

  &__icon {
    position: absolute;
    top: 50%;
    left: $space-6;
    width: 1rem;
    height: 1rem;
    color: $color-text-soft;
    transform: translateY(-50%);
  }

  &__input {
    padding-left: 2.25rem;
  }
}
</style>
