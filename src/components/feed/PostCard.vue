<script setup>
import { computed, nextTick, ref } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import GrrButton from '@/components/common/GrrButton.vue'
import PostComments from '@/components/feed/PostComments.vue'
import PostEditDialog from '@/components/feed/PostEditDialog.vue'
import ReportDialog from '@/components/feed/ReportDialog.vue'
import GrrersDialog from '@/components/feed/GrrersDialog.vue'
import { useAuthStore } from '@/stores/auth'
import { useFeedStore } from '@/stores/feed'
import { usePhotosStore } from '@/stores/photos'
import { useConfirm } from '@/composables/useConfirm'
import { fullName } from '@/utils/text'
import { formatDistance } from '@/utils/geo'

// One line of "Novedades de tus amigos", Tuenti style: who, what, a small photo
// and discreet text actions. Not a big card.

// PROPS
const props = defineProps({
  postId: { type: String, required: true },
  /** { city, distanceKm } when shown in "Cerca de ti". */
  nearby: { type: Object, default: null },
})

// STORES
const auth = useAuthStore()
const feed = useFeedStore()
const photos = usePhotosStore()
const { confirm } = useConfirm()

// DATA
const comments = ref(null)
const commenting = ref(false)
const editing = ref(false)
const reporting = ref(false)
const showGrrers = ref(false)
const OWN_MENU = [
  { key: 'edit', label: 'Editar' },
  { key: 'delete', label: 'Eliminar', danger: true },
]
const OTHER_MENU = [
  { key: 'hide', label: 'Ocultar' },
  { key: 'report', label: 'Reportar', danger: true },
]

// COMPUTED
const post = computed(() => feed.posts[props.postId])
const isOwn = computed(() => post.value?.authorId === auth.meId)
const titleId = computed(() => `post-${props.postId}-author`)
const showComments = computed(() => commenting.value || (post.value?.commentCount ?? 0) > 0)

// The town; the distance only replaces it when the author hides the town.
const placeLabel = computed(() => {
  if (!props.nearby) return ''
  const { city, distanceKm } = props.nearby
  if (city) return city
  return distanceKm === null ? '' : formatDistance(distanceKm)
})

// METHODS
const onMenu = async (key) => {
  if (key === 'edit') editing.value = true
  else if (key === 'report') reporting.value = true
  else if (key === 'hide') feed.hidePost(props.postId)
  else if (key === 'delete') {
    const ok = await confirm({
      title: 'Eliminar publicación',
      message: 'Se eliminarán también sus comentarios y Grr. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    })
    if (ok) feed.deletePost(props.postId)
  }
}

const openPhoto = () => photos.openSingle(post.value.photo.id)

const comment = async () => {
  commenting.value = true
  await nextTick()
  comments.value?.focus()
}
</script>

<template>
  <article v-if="post" class="item" :aria-labelledby="titleId">
    <RouterLink class="item__avatar" :to="{ name: 'profile', params: { id: post.author.id } }" tabindex="-1" aria-hidden="true">
      <UserAvatar :person="post.author" size="md" />
    </RouterLink>

    <div class="item__body">
      <p class="item__line">
        <PersonLink :id="titleId" :person="post.author" />
        <span v-if="post.text" class="item__text user-text">{{ post.text }}</span>
        <span v-else class="item__action">ha subido una foto</span>
      </p>

      <button v-if="post.photo" type="button" class="item__photo" aria-label="Abrir fotografía" @click="openPhoto">
        <img v-if="post.photo.url" :src="post.photo.url" alt="" loading="lazy" decoding="async" />
      </button>

      <p class="item__meta">
        <RouterLink class="item__time" :to="{ name: 'post', params: { id: post.id } }">
          <RelativeTime :value="post.createdAt" />
        </RouterLink>
        <span v-if="post.updatedAt" class="item__sep">editado</span>
        <span v-if="placeLabel" class="item__sep">{{ placeLabel }}</span>
        <span class="item__sep">
          <GrrButton
            compact
            :active="post.hasGrr"
            :count="post.grrCount"
            :disabled="feed.grrPending.has(post.id)"
            target="publicación"
            @toggle="feed.toggleGrr(post.id)"
          />
          <button v-if="post.grrCount" type="button" class="item__link" @click="showGrrers = true">quién</button>
        </span>
        <span class="item__sep">
          <button type="button" class="item__link" :aria-expanded="showComments" @click="comment">
            Comentar<template v-if="post.commentCount"> ({{ post.commentCount }})</template>
          </button>
        </span>
      </p>

      <PostComments v-if="showComments" ref="comments" :post="post" :show-form="commenting" />
    </div>

    <DropdownMenu
      class="item__menu"
      :label="`Opciones de la publicación de ${fullName(post.author)}`"
      :items="isOwn ? OWN_MENU : OTHER_MENU"
      @select="onMenu"
    />

    <PostEditDialog v-if="isOwn" :open="editing" :post="post" @close="editing = false" />
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

  &__photo {
    @include reset-button;
    display: block;
    width: fit-content;
    max-width: min(100%, 17rem);
    margin-top: $space-2;
    padding: 3px;
    background: $color-surface;
    border: 1px solid $color-border-strong;
    border-radius: $radius-sm;
    cursor: zoom-in;

    img {
      display: block;
      max-width: 100%;
      max-height: 13rem;
      object-fit: cover;
    }

    &:hover {
      border-color: $color-brand;
    }
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
