<script setup>
import { onMounted } from 'vue'
import { Check, UserPlus } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import { useFriendsStore } from '@/stores/friends'
import { fullName, plural } from '@/utils/text'

// "Quizá conozcas a": a few friends of friends, one line each.

// STORES
const friends = useFriendsStore()

// LIFECYCLE
onMounted(() => friends.loadSuggestions())
</script>

<template>
  <section v-if="friends.suggestions.items.length" class="panel suggestions" aria-labelledby="suggestions-title">
    <h2 id="suggestions-title" class="panel-title">Quizá conozcas a</h2>
    <ul class="suggestions__list" role="list">
      <li v-for="person in friends.suggestions.items" :key="person.id" class="suggestions__item">
        <UserAvatar :person="person" size="sm" />
        <PersonLink class="suggestions__name" :person="person" :title="plural(person.mutualFriends, 'amigo en común', 'amigos en común')" />
        <span v-if="person.friendship === 'request_sent'" class="suggestions__sent" :title="`Solicitud enviada a ${fullName(person)}`">
          <Check aria-hidden="true" />
          <span class="visually-hidden">Solicitud enviada</span>
        </span>
        <button
          v-else-if="person.friendship === 'none'"
          type="button"
          class="suggestions__add"
          :aria-label="`Añadir a ${fullName(person)} como amigo`"
          :title="person.canSendRequest ? 'Añadir amigo' : 'Esta persona no acepta solicitudes ahora mismo'"
          :disabled="friends.busy.has(person.id) || !person.canSendRequest"
          @click="friends.send(person.id)"
        >
          <UserPlus aria-hidden="true" />
        </button>
      </li>
    </ul>
  </section>
</template>

<style lang="scss" scoped>
.suggestions {
  &__list {
    margin: 0;
    padding: $space-1 $space-3;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: $space-2;
    padding: $space-1 0;
  }

  &__name {
    @include truncate;
    flex: 1;
    min-width: 0;
    font-size: $fs-sm;
  }

  &__add,
  &__sent {
    display: flex;
    flex-shrink: 0;
    align-items: center;
    justify-content: center;
    width: 1.75rem;
    height: 1.75rem;
    border-radius: $radius-sm;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }

  &__add {
    @include reset-button;
    color: $color-link;

    &:hover:not(:disabled) {
      background: $color-surface-hover;
    }

    &:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    &:focus-visible {
      @include focus-ring;
    }
  }

  &__sent {
    color: $color-success;
  }
}
</style>
