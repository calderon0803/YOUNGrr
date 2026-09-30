<script setup>
import { onBeforeUnmount, ref, watch } from 'vue'
import ActivityBlock from '@/components/feed/ActivityBlock.vue'
import AsyncState from '@/components/common/AsyncState.vue'

// Friends' news: a list state of activity blocks
// ({ blocks, status, error, hasMore, loadingMore }), loading more on scroll.

// PROPS
const props = defineProps({
  list: { type: Object, required: true },
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
  <AsyncState :status="list.status" :error="list.error" :empty="list.blocks.length === 0" skeleton="list" :skeleton-count="4" @retry="emit('retry')">
    <template #empty>
      <slot name="empty" />
    </template>

    <TransitionGroup tag="div" name="activity-list" class="activity-list">
      <ActivityBlock v-for="block in list.blocks" :key="`${block.person.id}:${block.day}`" :block="block" />
    </TransitionGroup>

    <div v-if="list.hasMore" ref="sentinel" class="activity-list__more">
      <button type="button" class="btn btn--ghost btn--sm" :disabled="list.loadingMore" @click="emit('more')">
        {{ list.loadingMore ? 'Cargando…' : 'Ver más' }}
      </button>
    </div>
    <p v-else-if="list.blocks.length > 3" class="activity-list__end">No hay más novedades de los últimos días.</p>
  </AsyncState>
</template>

<style lang="scss" scoped>
// One block with dividers, like Tuenti's list of friends' news.
.activity-list {
  display: flex;
  flex-direction: column;

  > * + * {
    border-top: 1px solid $color-border;
  }

  &__more,
  &__end {
    display: flex;
    justify-content: center;
    padding: $space-2 0 $space-3;
    border-top: 1px solid $color-border;
  }

  &__end {
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}

.activity-list-enter-active {
  transition:
    opacity 260ms $ease-out,
    transform 260ms $ease-out;
}

.activity-list-enter-from {
  opacity: 0;
  transform: translateY(-0.5rem);
}

.activity-list-leave-active {
  transition: opacity 160ms;
}

.activity-list-leave-to {
  opacity: 0;
}
</style>
