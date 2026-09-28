<script setup>
import { CircleAlert } from 'lucide-vue-next'
import StateMessage from '@/components/common/StateMessage.vue'
import SkeletonBlock from '@/components/common/SkeletonBlock.vue'

// Wraps a data section: loading → error (retry only if it can help) → empty → content.

// PROPS
defineProps({
  status: { type: String, required: true },
  error: { type: String, default: null },
  /** ApiError code: for missing or unavailable content, retrying makes no sense. */
  errorCode: { type: String, default: null },
  empty: { type: Boolean, default: false },
  skeleton: { type: String, default: 'list', validator: (v) => ['list', 'post', 'grid', 'block'].includes(v) },
  skeletonCount: { type: Number, default: 3 },
})

const emit = defineEmits(['retry'])

// DATA
const NO_RETRY = ['not_found', 'forbidden', 'not_available']
</script>

<template>
  <div v-if="status === 'loading' || status === 'idle'" aria-busy="true">
    <slot name="loading">
      <SkeletonBlock :variant="skeleton" :count="skeletonCount" />
    </slot>
  </div>
  <StateMessage v-else-if="status === 'error' && NO_RETRY.includes(errorCode)" :title="error ?? 'No hay nada aquí.'" />
  <StateMessage v-else-if="status === 'error'" tone="error" :icon="CircleAlert" title="No se ha podido cargar" :text="error ?? ''">
    <button type="button" class="btn btn--secondary" @click="emit('retry')">Reintentar</button>
  </StateMessage>
  <slot v-else-if="empty" name="empty" />
  <slot v-else />
</template>
