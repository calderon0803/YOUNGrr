<script setup>
import { computed } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import { useAuthStore } from '@/stores/auth'
import { useGroupsStore } from '@/stores/groups'
import { useModerationStore } from '@/stores/moderation'
import { useConfirm } from '@/composables/useConfirm'
import { fullName } from '@/utils/text'
import { ROLE_LABEL } from '@/utils/groups'

// The group's people. Administrators see the requests to join and remove
// members; the owner also names administrators and can hand the group over.
// Place groups have no owner: the moderators in them name administrators, and
// everyone only sees their friends (and who administers it) by name.

// PROPS
const props = defineProps({
  groupId: { type: String, required: true },
})

// STORES
const auth = useAuthStore()
const groups = useGroupsStore()
const moderation = useModerationStore()
const { confirm } = useConfirm()

// COMPUTED
const group = computed(() => groups.groups[props.groupId])
const state = computed(() => groups.details[props.groupId])
const myRole = computed(() => group.value?.myRole)
const isAdmin = computed(() => !!group.value?.canManage)
const isPlace = computed(() => group.value?.kind === 'place')
// Who names administrators: the owner, or in place groups the moderators.
const namesAdmins = computed(() => myRole.value === 'owner' || (isPlace.value && moderation.isModerator))

// METHODS
const actionsFor = (member) => {
  if (member.person.id === auth.meId || member.role === 'owner') return []
  const items = []
  if (namesAdmins.value) {
    items.push(member.role === 'admin' ? { key: 'member', label: 'Quitar de la administración' } : { key: 'admin', label: 'Hacer administrador' })
    if (!isPlace.value) items.push({ key: 'owner', label: 'Pasarle el grupo' })
  }
  if (isAdmin.value && (member.role === 'member' || namesAdmins.value)) items.push({ key: 'remove', label: 'Quitar del grupo', danger: true })
  return items
}

const onAction = async (member, key) => {
  const name = member.person.firstName
  if (key === 'remove') {
    const ok = await confirm({ title: 'Quitar del grupo', message: `${name} dejará de ver el Gallinero y los eventos del grupo.`, confirmLabel: 'Quitar', danger: true })
    if (ok) groups.removeMember(props.groupId, member.person.id)
  } else if (key === 'owner') {
    const ok = await confirm({
      title: 'Pasar el grupo',
      message: `${name} será propietario del grupo y tú pasarás a administrarlo.`,
      confirmLabel: 'Pasar el grupo',
    })
    if (ok) groups.setRole(props.groupId, member.person.id, 'owner')
  } else {
    groups.setRole(props.groupId, member.person.id, key)
  }
}
</script>

<template>
  <div v-if="state" class="group-members">
    <section v-if="isAdmin && state.requests.length" class="group-members__section" aria-labelledby="group-requests-title">
      <h3 id="group-requests-title" class="group-members__title">Quieren entrar ({{ state.requests.length }})</h3>
      <ul class="group-members__list" role="list">
        <li v-for="request in state.requests" :key="request.person.id" class="group-members__item">
          <UserAvatar :person="request.person" size="sm" />
          <span class="group-members__text">
            <PersonLink :person="request.person" />
            <span class="group-members__sub"><RelativeTime :value="request.createdAt" /></span>
          </span>
          <span class="group-members__actions">
            <button type="button" class="btn btn--primary btn--sm" @click="groups.answerRequest(groupId, request.person.id, true)">Aceptar</button>
            <button type="button" class="btn btn--secondary btn--sm" @click="groups.answerRequest(groupId, request.person.id, false)">Rechazar</button>
          </span>
        </li>
      </ul>
    </section>

    <section class="group-members__section" aria-labelledby="group-people-title">
      <h3 id="group-people-title" class="group-members__title">{{ group.memberCount }} {{ group.memberCount === 1 ? 'persona' : 'personas' }}</h3>
      <p v-if="isPlace" class="group-members__note">De la gente del grupo solo ves a tus amigos y a quien lo administra.</p>
      <ul class="group-members__list" role="list">
        <li v-for="member in state.members" :key="member.person.id" class="group-members__item">
          <UserAvatar :person="member.person" size="sm" />
          <span class="group-members__text">
            <PersonLink :person="member.person" />
            <span v-if="member.role !== 'member'" class="group-members__tag">{{ ROLE_LABEL[member.role] }}</span>
          </span>
          <DropdownMenu
            v-if="actionsFor(member).length"
            :label="`Opciones para ${fullName(member.person)}`"
            :items="actionsFor(member)"
            @select="(key) => onAction(member, key)"
          />
        </li>
      </ul>
    </section>
  </div>
</template>

<style lang="scss" scoped>
.group-members {
  display: flex;
  flex-direction: column;
  gap: $space-4;
  padding: $space-3;

  &__title {
    margin-bottom: $space-2;
    font-weight: 700;
  }

  &__note {
    margin-bottom: $space-2;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__list {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    margin: 0;
    padding: 0;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: $space-2;
  }

  &__text {
    display: flex;
    flex: 1;
    flex-wrap: wrap;
    align-items: center;
    gap: 0 $space-2;
    min-width: 0;
  }

  &__sub {
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__tag {
    padding: 0.05rem $space-2;
    border-radius: $radius-sm;
    background: $color-brand-tint;
    color: $color-brand-strong;
    font-size: $fs-xs;
    font-weight: 700;
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    gap: $space-1;
  }
}
</style>
