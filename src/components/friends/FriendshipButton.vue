<script setup>
import { computed } from 'vue'
import { Check, UserPlus } from 'lucide-vue-next'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import { useFriendsStore } from '@/stores/friends'
import { useConfirm } from '@/composables/useConfirm'
import { fullName } from '@/utils/text'

// PROPS
const props = defineProps({
  /** Needs id, firstName, lastName, friendship and canSendRequest. */
  person: { type: Object, required: true },
  size: { type: String, default: 'md', validator: (v) => ['sm', 'md'].includes(v) },
})

// STORES
const friends = useFriendsStore()
const { confirm } = useConfirm()

// COMPUTED
const busy = computed(() => friends.busy.has(props.person.id))
const sizeClass = computed(() => (props.size === 'sm' ? 'btn--sm' : ''))

// METHODS
const removeFriend = async () => {
  const ok = await confirm({
    title: 'Eliminar amigo',
    message: `${fullName(props.person)} dejará de ver tus publicaciones y tú las suyas.`,
    confirmLabel: 'Eliminar amigo',
    danger: true,
  })
  if (ok) friends.remove(props.person.id)
}
</script>

<template>
  <div class="friendship">
    <template v-if="person.friendship === 'friends'">
      <span class="friendship__badge">
        <Check aria-hidden="true" />
        Amigos
      </span>
      <DropdownMenu
        :label="`Opciones de amistad con ${fullName(person)}`"
        :items="[{ key: 'remove', label: 'Eliminar amigo', danger: true }]"
        @select="removeFriend"
      />
    </template>

    <button
      v-else-if="person.friendship === 'request_sent'"
      type="button"
      class="btn btn--secondary"
      :class="sizeClass"
      :disabled="busy"
      @click="friends.cancel(person.id)"
    >
      Cancelar solicitud
    </button>

    <template v-else-if="person.friendship === 'request_received'">
      <button type="button" class="btn btn--primary" :class="sizeClass" :disabled="busy" @click="friends.accept(person.id)">
        Aceptar
      </button>
      <button type="button" class="btn btn--secondary" :class="sizeClass" :disabled="busy" @click="friends.reject(person.id)">
        Rechazar
      </button>
    </template>

    <button
      v-else-if="person.friendship === 'none'"
      type="button"
      class="btn btn--soft"
      :class="sizeClass"
      :disabled="busy || !person.canSendRequest"
      :title="person.canSendRequest ? undefined : 'Esta persona no acepta solicitudes ahora mismo'"
      @click="friends.send(person.id)"
    >
      <UserPlus aria-hidden="true" />
      Añadir amigo
    </button>
  </div>
</template>

<style lang="scss" scoped>
.friendship {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: center;
  gap: $space-2;

  &__badge {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    font-size: $fs-sm;
    font-weight: 600;
    color: $color-success;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }
}
</style>
