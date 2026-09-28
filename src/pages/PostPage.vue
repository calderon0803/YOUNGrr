<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ArrowLeft } from 'lucide-vue-next'
import PostCard from '@/components/feed/PostCard.vue'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import { useFeedStore } from '@/stores/feed'
import { useNotificationsStore } from '@/stores/notifications'
import { errorMessage } from '@/services/errors'
import { useOwnerRedirect } from '@/composables/useOwnerRedirect'

// STORES
const route = useRoute()
const feed = useFeedStore()
const notifications = useNotificationsStore()
const { redirectToOwner } = useOwnerRedirect()

// DATA
const status = ref('loading')
const error = ref(null)

// COMPUTED
const postId = computed(() => String(route.params.id))
const exists = computed(() => !!feed.posts[postId.value])

// METHODS
const load = async () => {
  status.value = exists.value ? 'success' : 'loading'
  error.value = null
  try {
    await feed.loadPost(postId.value)
    status.value = 'success'
    notifications.markSeen({ targetId: postId.value })
  } catch (e) {
    if (redirectToOwner(e?.code, e?.details?.ownerId)) return
    error.value = errorMessage(e)
    status.value = 'error'
  }
}

// WATCHERS
watch(postId, load, { immediate: true })
</script>

<template>
  <div class="post-page">
    <RouterLink class="post-page__back" :to="{ name: 'home' }">
      <ArrowLeft aria-hidden="true" />
      Volver al inicio
    </RouterLink>
    <h1 class="visually-hidden">Novedad</h1>
    <AsyncState :status="status" :error="error" :empty="!exists" skeleton="post" :skeleton-count="1" @retry="load">
      <template #empty>
        <div class="panel"><StateMessage title="Esto ya no existe." text="Puede que lo hayan eliminado o cambiado por un estado nuevo." /></div>
      </template>
      <div class="panel"><PostCard :post-id="postId" /></div>
    </AsyncState>
  </div>
</template>

<style lang="scss" scoped>
.post-page {
  display: flex;
  flex-direction: column;
  gap: $space-3;
  max-width: 42rem;

  &__back {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    padding: 0 $space-3;
    font-weight: 600;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }
}
</style>
