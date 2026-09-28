<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ArrowLeft, Images } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import { notificationsService } from '@/services/notifications.service'
import { photoNewsTypes } from '@/services/notifications.groups'
import { errorMessage } from '@/services/errors'
import { usePhotosStore } from '@/stores/photos'
import { useNotificationsStore } from '@/stores/notifications'

// When a home counter about photos has several (comments, Grr, tags, shares),
// this lists exactly those photos with who did what. Opening a photo marks
// only that one as seen, so the counter goes down one by one.

// STORES
const route = useRoute()
const photos = usePhotosStore()
const notifications = useNotificationsStore()

// DATA
const TITLES = {
  comments_photos: 'Comentarios nuevos en tus fotos',
  grr_photos: 'Grr nuevos en tus fotos',
  tags: 'Fotos en las que te han etiquetado',
  owners_accepted: 'Amigos que han aceptado compartir tus fotos',
  shares: 'Te invitan a compartir estas fotos',
}
const status = ref('loading')
const error = ref(null)
const items = ref([])

// COMPUTED
const group = computed(() => (typeof route.query.grupo === 'string' && photoNewsTypes(route.query.grupo) ? route.query.grupo : 'comments_photos'))
const title = computed(() => TITLES[group.value] ?? 'Novedades de tus fotos')

// METHODS
const names = (people) => {
  const unique = [...new Map(people.map((p) => [p.id, p.firstName])).values()]
  if (unique.length === 1) return unique[0]
  if (unique.length <= 3) return `${unique.slice(0, -1).join(', ')} y ${unique.at(-1)}`
  return `${unique.slice(0, 2).join(', ')} y ${unique.length - 2} más`
}

/** One line per kind of news on the photo: "2 comentarios nuevos de Ana y Pablo". */
const lines = (entry) => {
  const byType = {}
  for (const item of entry.items) (byType[item.type] ??= []).push(item)
  const out = []
  const actors = (type) => byType[type].map((i) => i.actor)
  if (byType.comment_photo) {
    const n = byType.comment_photo.length
    out.push(`${n} ${n === 1 ? 'comentario nuevo' : 'comentarios nuevos'} de ${names(actors('comment_photo'))}`)
  }
  if (byType.grr_photo) out.push(`Grr de ${names(actors('grr_photo'))}`)
  if (byType.photo_tag) out.push(`${byType.photo_tag.length === 1 ? 'Te ha etiquetado' : 'Te han etiquetado'} ${names(actors('photo_tag'))}`)
  if (byType.photo_owner_accepted) out.push(`${names(actors('photo_owner_accepted'))} ya la comparte contigo`)
  if (byType.photo_owner_invite) out.push(`${names(actors('photo_owner_invite'))} quiere compartirla contigo. Ábrela para responder.`)
  return out
}

const load = async () => {
  status.value = items.value.length ? 'success' : 'loading'
  error.value = null
  try {
    items.value = await notificationsService.getPhotoNews(photoNewsTypes(group.value))
    status.value = 'success'
  } catch (e) {
    error.value = errorMessage(e)
    status.value = 'error'
  }
}

const open = (photoId) =>
  photos.openSingle(
    photoId,
    items.value.map((i) => i.photo.id),
  )

// WATCHERS
watch(group, load, { immediate: true })
// Back from the viewer: what was seen leaves the list and the counters.
watch(
  () => photos.viewer.open,
  (isOpen) => {
    if (isOpen) return
    load()
    notifications.loadSummary()
  },
)
</script>

<template>
  <div class="photo-news">
    <RouterLink class="photo-news__back" :to="{ name: 'home' }">
      <ArrowLeft aria-hidden="true" />
      Volver al inicio
    </RouterLink>

    <section class="panel" aria-labelledby="photo-news-title">
      <h1 id="photo-news-title" class="panel-title">{{ title }}</h1>
      <AsyncState :status="status" :error="error" :empty="!items.length" skeleton="list" :skeleton-count="3" @retry="load">
        <template #empty>
          <StateMessage :icon="Images" title="Ya lo has visto todo." text="Cuando haya novedades en tus fotos, aparecerán en Inicio.">
            <RouterLink class="btn btn--primary" :to="{ name: 'home' }">Ir a Inicio</RouterLink>
          </StateMessage>
        </template>

        <ul class="photo-news__list" role="list">
          <li v-for="entry in items" :key="entry.photo.id">
            <button type="button" class="photo-news__item" @click="open(entry.photo.id)">
              <span class="photo-news__thumb">
                <img v-if="entry.photo.url" :src="entry.photo.url" alt="" loading="lazy" decoding="async" />
              </span>
              <span class="photo-news__body">
                <span v-for="line in lines(entry)" :key="line" class="photo-news__line">{{ line }}</span>
                <span class="photo-news__meta">
                  <template v-if="entry.photo.albumTitle">{{ entry.photo.albumTitle }} · </template>
                  <RelativeTime :value="entry.items[0].createdAt" />
                </span>
              </span>
            </button>
          </li>
        </ul>
      </AsyncState>
    </section>
  </div>
</template>

<style lang="scss" scoped>
.photo-news {
  display: flex;
  flex-direction: column;
  gap: $space-3;
  max-width: 40rem;
  margin: 0 auto;

  &__back {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    padding: 0 $space-3;
    font-size: $fs-sm;

    svg {
      width: 1rem;
      height: 1rem;
    }
  }

  &__list {
    margin: 0;
    padding: 0;

    li + li {
      border-top: 1px solid $color-border;
    }
  }

  &__item {
    @include reset-button;
    display: flex;
    align-items: center;
    gap: $space-3;
    width: 100%;
    padding: $space-3;
    text-align: left;

    &:hover {
      background: $color-surface-hover;
    }

    &:focus-visible {
      @include focus-ring(-2px);
    }
  }

  &__thumb {
    flex-shrink: 0;
    width: 4rem;
    height: 4rem;
    overflow: hidden;
    border: 1px solid $color-border-strong;
    border-radius: $radius-sm;
    background: $color-surface-alt;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__body {
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
    min-width: 0;
  }

  &__line {
    font-weight: 600;
    color: $color-text;
  }

  &__meta {
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
