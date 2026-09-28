<script setup>
import { ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import { useFeedStore } from '@/stores/feed'
import { errorMessage } from '@/services/errors'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  targetType: { type: String, required: true },
  targetId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const feed = useFeedStore()

// DATA
const status = ref('idle')
const error = ref(null)
const people = ref([])

// METHODS
const load = async () => {
  status.value = 'loading'
  try {
    people.value = await feed.loadGrrers(props.targetType, props.targetId)
    status.value = 'success'
  } catch (e) {
    error.value = errorMessage(e)
    status.value = 'error'
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => open && load(),
  { immediate: true },
)
</script>

<template>
  <BaseModal :open="open" title="Han hecho Grr" size="sm" @close="emit('close')">
    <AsyncState :status="status" :error="error" :empty="people.length === 0" @retry="load">
      <template #empty>
        <StateMessage compact title="Todavía nadie ha hecho Grr." />
      </template>
      <ul class="grrers" role="list">
        <li v-for="person in people" :key="person.id" class="grrers__item">
          <UserAvatar :person="person" size="sm" />
          <PersonLink :person="person" @click="emit('close')" />
        </li>
      </ul>
    </AsyncState>
  </BaseModal>
</template>

<style lang="scss" scoped>
.grrers {
  margin: 0;

  &__item {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-2 0;

    & + & {
      border-top: 1px solid $color-border;
    }
  }
}
</style>
