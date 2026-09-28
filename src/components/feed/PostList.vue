<script setup>
import { onBeforeUnmount, ref, watch } from 'vue'
import PostCard from '@/components/feed/PostCard.vue'
import AsyncState from '@/components/common/AsyncState.vue'

// Renders a feed or timeline list state ({ ids, status, error, hasMore, loadingMore }).

// PROPS
const props = defineProps({
  list: { type: Object, required: true },
  /** Optional per-post extra info, e.g. { [postId]: { city, distanceKm } } for "Cerca de ti". */
  meta: { type: Object, default: null },
})

const emit = defineEmits(['retry', 'more'])

// DATA
const sentinel = ref(null)
let observer = null

// METHODS
const observe = (el) => {
  observer?.disconnect()
  if (!el || !('IntersectionObserver' in window)) return
  observer = new IntersectionObserver(
    ([entry]) => {
      if (entry.isIntersecting && props.list.hasMore && !props.list.loadingMore) emit('more')
    },
    { rootMargin: '600px 0px' },
  )
  observer.observe(el)
}

// LIFECYCLE
onBeforeUnmount(() => observer?.disconnect())

// WATCHERS
watch(sentinel, observe)
</script>

<template>
  <AsyncState :status="list.status" :error="list.error" :empty="list.ids.length === 0" skeleton="post" :skeleton-count="2" @retry="emit('retry')">
    <template #empty>
      <slot name="empty" />
    </template>

    <TransitionGroup tag="div" name="post-list" class="post-list">
      <PostCard v-for="id in list.ids" :key="id" :post-id="id" :nearby="meta?.[id] ?? null" />
    </TransitionGroup>

    <div v-if="list.hasMore" ref="sentinel" class="post-list__more">
      <button type="button" class="btn btn--secondary" :disabled="list.loadingMore" @click="emit('more')">
        {{ list.loadingMore ? 'Cargando…' : 'Ver publicaciones anteriores' }}
      </button>
    </div>
    <p v-else-if="list.ids.length > 3" class="post-list__end">No hay publicaciones más antiguas.</p>
  </AsyncState>
</template>

<style lang="scss" scoped>
.post-list {
  display: flex;
  flex-direction: column;
  gap: $space-3;

  &__more,
  &__end {
    display: flex;
    justify-content: center;
    padding: $space-4 0;
  }

  &__end {
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}

.post-list-enter-active {
  transition:
    opacity 260ms $ease-out,
    transform 260ms $ease-out;
}

.post-list-enter-from {
  opacity: 0;
  transform: translateY(-0.5rem);
}

.post-list-leave-active {
  transition: opacity 160ms;
}

.post-list-leave-to {
  opacity: 0;
}
</style>
