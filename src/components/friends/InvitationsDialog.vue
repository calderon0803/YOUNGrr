<script setup>
import BaseModal from '@/components/common/BaseModal.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import InvitationLink from '@/components/friends/InvitationLink.vue'
import { useInvitationsStore } from '@/stores/invitations'
import { useConfirm } from '@/composables/useConfirm'

// Invitations you have sent: pending ones (link to copy, cancel) and accepted.

// PROPS
defineProps({
  open: { type: Boolean, required: true },
})

const emit = defineEmits(['close'])

// STORES
const invitations = useInvitationsStore()
const { confirm } = useConfirm()

// METHODS
const cancel = async (invitation) => {
  const ok = await confirm({
    title: 'Cancelar invitación',
    message: `El enlace para ${invitation.email} dejará de funcionar y recuperarás la invitación.`,
    confirmLabel: 'Cancelar invitación',
    danger: true,
  })
  if (ok) invitations.cancel(invitation.id)
}
</script>

<template>
  <BaseModal :open="open" title="Mis invitaciones" @close="emit('close')">
    <p class="invitations__available">
      Te quedan <strong>{{ invitations.state.available }}</strong>
      {{ invitations.state.available === 1 ? 'invitación' : 'invitaciones' }}.
    </p>
    <ul class="invitations" role="list">
      <li v-for="inv in invitations.state.items" :key="inv.id" class="invitations__item">
        <template v-if="inv.usedBy">
          <p><PersonLink :person="inv.usedBy" /> ya está en YOUNGrr</p>
          <p class="invitations__meta">{{ inv.email }} · se unió <RelativeTime :value="inv.usedAt" /></p>
        </template>
        <template v-else-if="inv.link">
          <p class="invitations__email">{{ inv.email }}</p>
          <p class="invitations__meta">
            Pendiente · enviada <RelativeTime :value="inv.createdAt" /> ·
            <button type="button" class="invitations__cancel" @click="cancel(inv)">Cancelar</button>
          </p>
          <InvitationLink :link="inv.link" :email="inv.email" />
        </template>
        <template v-else>
          <p class="invitations__email">{{ inv.email }}</p>
          <p class="invitations__meta">Caducada</p>
        </template>
      </li>
    </ul>
  </BaseModal>
</template>

<style lang="scss" scoped>
.invitations {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;

  &__available {
    margin-bottom: $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__item {
    display: flex;
    flex-direction: column;
    gap: $space-1;
    padding: $space-3 0;

    & + & {
      border-top: 1px solid $color-border;
    }
  }

  &__email {
    font-weight: 600;
  }

  &__meta {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__cancel {
    @include reset-button;
    color: $color-danger;
    font-size: $fs-sm;

    &:hover {
      text-decoration: underline;
    }
  }
}
</style>
