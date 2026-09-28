<script setup>
import { computed, onBeforeUnmount, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Images } from 'lucide-vue-next'
import StateMessage from '@/components/common/StateMessage.vue'
import { usePhotosStore } from '@/stores/photos'
import { useOwnerRedirect } from '@/composables/useOwnerRedirect'

// A single photo by link (e.g. from a notification). Without access, the viewer
// is sent to the owner's profile.

// STORES
const route = useRoute()
const router = useRouter()
const photos = usePhotosStore()
const { redirectToOwner } = useOwnerRedirect()

// DATA
let redirecting = false

// COMPUTED
const photoId = computed(() => String(route.params.id))

// METHODS
const leave = () => {
  if (window.history.state?.back) router.back()
  else router.replace({ name: 'home' })
}

// LIFECYCLE
onBeforeUnmount(() => {
  if (photos.viewer.open) photos.closeViewer()
})

// WATCHERS
watch(
  photoId,
  async (id) => {
    await photos.openSingle(id)
    const { detailErrorCode, detailOwnerId } = photos.viewer
    if (detailErrorCode === 'forbidden' && detailOwnerId) {
      redirecting = true
      photos.closeViewer()
      redirectToOwner(detailErrorCode, detailOwnerId)
    }
  },
  { immediate: true },
)

// Closing the viewer (or deleting the photo) leaves this page.
watch(
  () => photos.viewer.open,
  (open) => {
    if (!open && route.name === 'photo' && !redirecting) leave()
  },
)
</script>

<template>
  <div class="panel">
    <h1 class="visually-hidden">Fotografía</h1>
    <StateMessage :icon="Images" title="Abriendo la fotografía…">
      <button type="button" class="btn btn--secondary" @click="leave">Volver</button>
    </StateMessage>
  </div>
</template>
