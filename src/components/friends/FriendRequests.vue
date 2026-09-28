<script setup>
import { computed } from 'vue'
import { UserCheck } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PersonGrid from '@/components/friends/PersonGrid.vue'
import { useFriendsStore } from '@/stores/friends'

// STORES
const friends = useFriendsStore()

// COMPUTED
const incoming = computed(() => friends.requests.incoming.map((r) => toPerson(r, 'request_received')))
const outgoing = computed(() => friends.requests.outgoing.map((r) => toPerson(r, 'request_sent')))

// METHODS
const toPerson = (request, friendship) => ({ ...request.person, friendship, mutualFriends: request.mutualFriends, canSendRequest: false })
</script>

<template>
  <AsyncState :status="friends.requests.status" :error="friends.requests.error" :empty="!incoming.length && !outgoing.length" @retry="friends.loadRequests()">
    <template #empty>
      <StateMessage :icon="UserCheck" title="No tienes solicitudes pendientes." text="Cuando alguien quiera ser tu amigo, aparecerá aquí." />
    </template>
    <section v-if="incoming.length" aria-labelledby="incoming-title">
      <h2 id="incoming-title" class="panel-title">Quieren ser tus amigos</h2>
      <PersonGrid :people="incoming" label="Solicitudes recibidas" />
    </section>
    <section v-if="outgoing.length" aria-labelledby="outgoing-title">
      <h2 id="outgoing-title" class="panel-title">Solicitudes enviadas</h2>
      <PersonGrid :people="outgoing" label="Solicitudes enviadas" />
    </section>
  </AsyncState>
</template>
