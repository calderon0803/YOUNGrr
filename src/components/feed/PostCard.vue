<script setup>
import { computed, nextTick, ref } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import GrrButton from '@/components/common/GrrButton.vue'
import PhotoStrip from '@/components/photos/PhotoStrip.vue'
import PostComments from '@/components/feed/PostComments.vue'
import ReportDialog from '@/components/feed/ReportDialog.vue'
import GrrersDialog from '@/components/feed/GrrersDialog.vue'
import { useAuthStore } from '@/stores/auth'
import { useFeedStore } from '@/stores/feed'
import { usePhotosStore } from '@/stores/photos'
import { useConfirm } from '@/composables/useConfirm'
import { fullName } from '@/utils/text'
import { formatDistance } from '@/utils/geo'

// A status or a "ha subido N fotos al álbum" item, Tuenti style: who, what, a
// small photo strip and discreet text actions. Inside an activity block
// (`bare`) the person is already shown above, so only the content is rendered.

// PROPS
const props = defineProps({
  postId: { type: String, required: true },
  /** { city, distanceKm } when shown in "Cerca de ti". */
  nearby: { type: Object, default: null },
  /** Without avatar and name (inside an activity block). */
  bare: { type: Boolean, default: false },
  /** One compact line: comments open on the item's own page. */
  compact: { type: Boolean, default: false },
})

// STORES
const auth = useAuthStore()
const feed = useFeedStore()
const photos = usePhotosStore()
const { confirm } = useConfirm()

// DATA
const comments = ref(null)
const commenting = ref(false)
const reporting = ref(false)
const showGrrers = ref(false)
const OWN_MENU = [{ key: 'delete', label: 'Eliminar', danger: true }]
const OTHER_MENU = [{ key: 'report', label: 'Reportar', danger: true }]
const COMPACT_PHOTOS = 4

// COMPUTED
const post = computed(() => feed.posts[props.postId])
const isOwn = computed(() => post.value?.authorId === auth.meId)
const isAlbumUpload = computed(() => post.value?.kind === 'album_upload')
// An album upload whose photos were all deleted has nothing left to show.
const isVisible = computed(() => post.value && (!isAlbumUpload.value || post.value.photos.length > 0))
const titleId = computed(() => `post-${props.postId}-title`)
const showComments = computed(() => !props.compact && (commenting.value || (post.value?.commentCount ?? 0) > 0))
const uploadLabel = computed(() => {
  const n = post.value?.photoTotal ?? 0
  const label = n === 1 ? 'ha subido una foto al álbum' : `ha subido ${n} fotos al álbum`
  return props.bare ? `${label.charAt(0).toUpperCase()}${label.slice(1)}` : label
})
// Compact lines keep one row of thumbnails; "+N" links to the album.
const shownPhotos = computed(() => (props.compact ? (post.value?.photos ?? []).slice(0, COMPACT_PHOTOS) : (post.value?.photos ?? [])))
const hiddenPhotos = computed(() => (post.value?.photoTotal ?? 0) - shownPhotos.value.length)
const what = computed(() => (isAlbumUpload.value ? 'la novedad' : 'el estado'))

// The town; the distance only replaces it when the person hides the town.
const placeLabel = computed(() => {
  if (!props.nearby) return ''
  const { city, distanceKm } = props.nearby
  if (city) return city
  return distanceKm === null ? '' : formatDistance(distanceKm)
})

// METHODS
const onMenu = async (key) => {
  if (key === 'report') reporting.value = true
  else if (key === 'delete') {
    const ok = await confirm({
      title: isAlbumUpload.value ? 'Quitar de las novedades' : 'Borrar tu estado',
      message: isAlbumUpload.value
        ? 'Las fotos siguen en el álbum. Se eliminarán los comentarios y Grr de esta novedad.'
        : 'Se eliminarán también sus comentarios y Grr. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    })
    if (ok) feed.deletePost(props.postId)
  }
}

const openUploaded = (photoId) =>
  photos.openSingle(
    photoId,
    post.value.photos.map((p) => p.id),
  )

const comment = async () => {
  commenting.value = true
  await nextTick()
  comments.value?.focus()
}
</script>

<template>
  <article v-if="isVisible" class="item" :class="{ 'item--bare': bare }" :aria-labelledby="titleId">
    <RouterLink v-if="!bare" class="item__avatar" :to="{ name: 'profile', params: { id: post.author.id } }" tabindex="-1" aria-hidden="true">
      <UserAvatar :person="post.author" size="md" />
    </RouterLink>

    <div class="item__body">
      <p :id="titleId" class="item__line">
        <PersonLink v-if="!bare" :person="post.author" />
        <template v-if="isAlbumUpload">
          <span class="item__action">{{ uploadLabel }}</span>
          <RouterLink v-if="post.album" class="item__album" :to="{ name: 'album', params: { id: post.album.id } }">
            {{ post.album.title }}
          </RouterLink>
        </template>
        <span v-else class="item__text user-text">{{ post.text }}</span>
      </p>

      <PhotoStrip
        v-if="isAlbumUpload"
        label="Fotos subidas"
        :photos="shownPhotos"
        :small="compact"
        :more-count="hiddenPhotos"
        :more-to="post.album ? { name: 'album', params: { id: post.album.id } } : null"
        @open="openUploaded"
      />

      <p class="item__meta">
        <RouterLink class="item__time" :to="{ name: 'post', params: { id: post.id } }">
          <RelativeTime :value="post.createdAt" />
        </RouterLink>
        <span v-if="placeLabel" class="item__sep">{{ placeLabel }}</span>
        <span class="item__sep">
          <GrrButton
            compact
            :active="post.hasGrr"
            :count="post.grrCount"
            :disabled="feed.grrPending.has(post.id)"
            :target="isAlbumUpload ? 'esta novedad' : 'este estado'"
            @toggle="feed.toggleGrr(post.id)"
          />
          <button v-if="post.grrCount" type="button" class="item__link" @click="showGrrers = true">quién</button>
        </span>
        <span class="item__sep">
          <RouterLink v-if="compact" class="item__link" :to="{ name: 'post', params: { id: post.id } }">
            Comentar<template v-if="post.commentCount"> ({{ post.commentCount }})</template>
          </RouterLink>
          <button v-else type="button" class="item__link" :aria-expanded="showComments" @click="comment">
            Comentar<template v-if="post.commentCount"> ({{ post.commentCount }})</template>
          </button>
        </span>
      </p>

      <PostComments v-if="showComments" ref="comments" :post="post" :show-form="commenting" />
    </div>

    <DropdownMenu
      class="item__menu"
      :label="`Opciones de ${what} de ${fullName(post.author)}`"
      :items="isOwn ? OWN_MENU : OTHER_MENU"
      @select="onMenu"
    />

    <ReportDialog v-if="!isOwn" :open="reporting" :post-id="post.id" @close="reporting = false" />
    <GrrersDialog v-if="showGrrers" :open="showGrrers" target-type="post" :target-id="post.id" @close="showGrrers = false" />
  </article>
</template>

<style lang="scss" scoped>
.item {
  display: flex;
  align-items: flex-start;
  gap: $space-3;
  padding: $space-3;

  &--bare {
    padding: 0;
  }

  &__avatar {
    flex-shrink: 0;
  }

  &__body {
    flex: 1;
    min-width: 0;
  }

  &__line {
    line-height: 1.4;

    :deep(.person-link) {
      margin-right: 0.35rem;
    }
  }

  &__action {
    color: $color-text-muted;
  }

  &__album {
    margin-left: 0.35rem;
    font-weight: 700;
  }

  &__meta {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0 $space-1;
    margin-top: $space-1;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__time {
    color: inherit;
  }

  // "·" between meta items.
  &__sep {
    display: inline-flex;
    align-items: center;

    &::before {
      content: '·';
      margin-right: $space-1;
    }
  }

  &__link {
    @include reset-button;
    color: $color-link;
    font-size: $fs-sm;

    &:hover {
      text-decoration: underline;
    }
  }

  &__menu {
    flex-shrink: 0;
    margin: -0.25rem -0.25rem 0 0;

    :deep(.dropdown__trigger) {
      width: 1.875rem;
      min-height: 1.875rem;
    }
  }
}
</style>
