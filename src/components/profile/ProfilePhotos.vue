<script setup>
import { computed, onMounted } from 'vue'
import { Images } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PhotoGrid from '@/components/photos/PhotoGrid.vue'
import { usePhotosStore } from '@/stores/photos'

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

// STORES
const photos = usePhotosStore()

// COMPUTED
const userId = computed(() => props.view.profile.id)
const own = computed(() => photos.lists[`user:${userId.value}`] ?? { status: 'loading', ids: [], error: null })
const isSelf = computed(() => props.view.friendship === 'self')

// METHODS
const load = () => photos.loadUserPhotos(userId.value)

// LIFECYCLE
onMounted(load)
</script>

<template>
  <section class="panel profile-photos" aria-labelledby="uploaded-title">
    <h2 id="uploaded-title" class="visually-hidden">{{ isSelf ? 'Fotos que has subido' : `Fotos subidas por ${view.profile.firstName}` }}</h2>
    <AsyncState :status="own.status" :error="own.error" :empty="!own.ids.length" skeleton="grid" :skeleton-count="10" @retry="load">
      <template #empty>
        <StateMessage compact :icon="Images" title="Todavía no hay fotografías." />
      </template>
      <PhotoGrid :ids="own.ids" label="Fotografías subidas" />
    </AsyncState>
  </section>
</template>

<style lang="scss" scoped>
.profile-photos {
  overflow: hidden;
}
</style>
