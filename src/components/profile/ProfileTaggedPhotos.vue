<script setup>
import { computed, onMounted } from 'vue'
import { Tag } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import PhotoGrid from '@/components/photos/PhotoGrid.vue'
import { usePhotosStore } from '@/stores/photos'

// Photos where the person is tagged, uploaded by their friends. Each photo
// follows the uploader's profile privacy.

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

// STORES
const photos = usePhotosStore()

// COMPUTED
const userId = computed(() => props.view.profile.id)
const isSelf = computed(() => props.view.friendship === 'self')
const tagged = computed(() => photos.lists[`tagged:${userId.value}`] ?? { status: 'loading', ids: [], error: null })

// METHODS
const load = () => photos.loadTaggedPhotos(userId.value)

// LIFECYCLE
onMounted(load)
</script>

<template>
  <section class="panel tagged-photos" aria-labelledby="tagged-title">
    <h2 id="tagged-title" class="panel-title">{{ isSelf ? 'Fotos en las que sales' : `Fotos en las que sale ${view.profile.firstName}` }}</h2>
    <AsyncState :status="tagged.status" :error="tagged.error" :empty="!tagged.ids.length" skeleton="grid" :skeleton-count="6" @retry="load">
      <template #empty>
        <StateMessage
          compact
          :icon="Tag"
          :title="isSelf ? 'Todavía no te han etiquetado en ninguna foto.' : 'Todavía no hay fotos en las que salga.'"
          :text="isSelf ? 'Cuando un amigo te etiquete, la foto aparecerá aquí aunque la haya subido él.' : ''"
        />
      </template>
      <PhotoGrid :ids="tagged.ids" label="Fotos con etiqueta" />
    </AsyncState>
  </section>
</template>

<style lang="scss" scoped>
.tagged-photos {
  overflow: hidden;
}
</style>
