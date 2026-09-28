<script setup>
import BaseModal from '@/components/common/BaseModal.vue'
import { useConfirm } from '@/composables/useConfirm'

// DATA
const { state, settle } = useConfirm()
</script>

<template>
  <BaseModal :open="state.open" :title="state.title" size="sm" @close="settle(false)">
    <p v-if="state.message" class="confirm__message">{{ state.message }}</p>
    <template #footer>
      <button type="button" class="btn btn--secondary" @click="settle(false)">Cancelar</button>
      <button type="button" class="btn" :class="state.danger ? 'btn--danger' : 'btn--primary'" autofocus @click="settle(true)">
        {{ state.confirmLabel }}
      </button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.confirm__message {
  color: $color-text-muted;
}
</style>
