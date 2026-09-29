<script setup>
import { computed, onMounted, ref } from 'vue'
import { ImagePlus, Images } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PhotoGrid from '@/components/photos/PhotoGrid.vue'
import PhotoUploadDialog from '@/components/photos/PhotoUploadDialog.vue'
import { usePhotosStore } from '@/stores/photos'

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

// STORES
const photos = usePhotosStore()

// DATA
const uploading = ref(false)

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
    <div v-if="isSelf" class="profile-photos__head">
      <button type="button" class="btn btn--soft btn--sm" @click="uploading = true">
        <ImagePlus aria-hidden="true" />
        Subir fotos
      </button>
    </div>
    <AsyncState :status="own.status" :error="own.error" :empty="!own.ids.length" skeleton="grid" :skeleton-count="10" @retry="load">
      <template #empty>
        <StateMessage compact :icon="Images" title="Todavía no hay fotografías." />
      </template>
      <PhotoGrid :ids="own.ids" label="Fotografías subidas" />
    </AsyncState>
    <PhotoUploadDialog v-if="isSelf" :open="uploading" @close="uploading = false" />
  </section>
</template>

<style lang="scss" scoped>
.profile-photos {
  overflow: hidden;

  &__head {
    display: flex;
    justify-content: flex-end;
    padding: $space-3 $space-4 0;
  }
}
</style>
