<script setup>
import { computed, onMounted, ref } from 'vue'
import { Check, UserPlus } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { useFriendsStore } from '@/stores/friends'
import { fullName, plural } from '@/utils/text'
import { SUGGESTIONS_SHOWN } from '@/config/app'

// "Quizá conozcas a": people with at least one friend in common, most in common
// first. A few in Inicio, one line each; "Ver todas" opens the whole list.

// STORES
const friends = useFriendsStore()

// DATA
const showAll = ref(false)

// COMPUTED
const shown = computed(() => friends.suggestions.items.slice(0, SUGGESTIONS_SHOWN))
const total = computed(() => friends.suggestions.items.length)

// LIFECYCLE
onMounted(() => friends.loadSuggestions())
</script>

<template>
  <section v-if="total" class="panel suggestions" aria-labelledby="suggestions-title">
    <h2 id="suggestions-title" class="panel-title">Quizá conozcas a</h2>
    <ul class="suggestions__list" role="list">
      <li v-for="person in shown" :key="person.id" class="suggestions__item">
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
    <button v-if="total > SUGGESTIONS_SHOWN" type="button" class="suggestions__more" @click="showAll = true">Ver todas ({{ total }})</button>

    <BaseModal :open="showAll" title="Quizá conozcas a" @close="showAll = false">
      <ul class="suggestions__full" role="list">
        <li v-for="person in friends.suggestions.items" :key="person.id" class="suggestions__row">
          <UserAvatar :person="person" size="md" />
          <span class="suggestions__who">
            <PersonLink :person="person" @click="showAll = false" />
            <span class="suggestions__mutual">{{ plural(person.mutualFriends, 'amigo en común', 'amigos en común') }}</span>
          </span>
          <span v-if="person.friendship === 'request_sent'" class="suggestions__sent-label">
            <Check aria-hidden="true" />
            Enviada
          </span>
          <button
            v-else-if="person.friendship === 'none'"
            type="button"
            class="btn btn--soft btn--sm"
            :disabled="friends.busy.has(person.id) || !person.canSendRequest"
            @click="friends.send(person.id)"
          >
            <UserPlus aria-hidden="true" />
            Añadir
          </button>
        </li>
      </ul>
    </BaseModal>
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

  &__sent,
  &__sent-label {
    color: $color-success;
  }

  &__more {
    @include reset-button;
    display: block;
    padding: 0 $space-3 $space-2;
    font-size: $fs-sm;
    color: $color-link;

    &:hover {
      text-decoration: underline;
    }
  }

  &__full {
    display: flex;
    flex-direction: column;
    margin: 0;
    padding: 0;
  }

  &__row {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-2 0;

    & + & {
      border-top: 1px solid $color-border;
    }
  }

  &__who {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
  }

  &__mutual {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__sent-label {
    display: inline-flex;
    flex-shrink: 0;
    align-items: center;
    gap: $space-1;
    font-size: $fs-sm;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }
}
</style>
