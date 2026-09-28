<script setup>
import { computed, ref } from 'vue'
import { MessageSquare } from 'lucide-vue-next'
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

// "Tú, Ana y 3 más han hecho Grr"
const grrSummary = computed(() => {
  const p = post.value
  if (!p || p.grrCount === 0) return ''
  if (p.hasGrr && p.grrCount === 1) return 'Has hecho Grr'
  const names = [...(p.hasGrr ? ['Tú'] : []), ...p.grrBy.map((person) => person.firstName)].slice(0, 2)
  const rest = p.grrCount - names.length
  const list = rest > 0 ? `${names.join(', ')} y ${rest} más` : names.join(' y ')
  const verb = p.hasGrr ? 'habéis' : p.grrCount === 1 ? 'ha' : 'han'
  return `${list} ${verb} hecho Grr`
})

const photoRatio = computed(() => {
  const photo = post.value?.photo
  if (!photo) return null
  // Clamp very tall photos so a single post never takes several screens.
  return Math.max(photo.width / photo.height, 0.8)
})

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
</script>

<template>
  <article v-if="post" class="post panel" :aria-labelledby="titleId">
    <header class="post__header">
      <RouterLink :to="{ name: 'profile', params: { id: post.author.id } }" tabindex="-1" aria-hidden="true">
        <UserAvatar :person="post.author" size="md" />
      </RouterLink>
      <div class="post__who">
        <PersonLink :id="titleId" :person="post.author" />
        <p class="post__meta">
          <RouterLink class="post__time" :to="{ name: 'post', params: { id: post.id } }">
            <RelativeTime :value="post.createdAt" />
          </RouterLink>
          <span v-if="post.updatedAt"> · editado</span>
          <span v-if="placeLabel" class="post__place"> · {{ placeLabel }}</span>
        </p>
      </div>
      <DropdownMenu
        class="post__menu"
        :label="`Opciones de la publicación de ${fullName(post.author)}`"
        :items="isOwn ? OWN_MENU : OTHER_MENU"
        @select="onMenu"
      />
    </header>

    <p v-if="post.text" class="post__text user-text">{{ post.text }}</p>

    <button v-if="post.photo" type="button" class="post__photo" :style="{ aspectRatio: photoRatio }" aria-label="Abrir fotografía" @click="openPhoto">
      <img :src="post.photo.url" alt="" loading="lazy" decoding="async" />
    </button>

    <button v-if="grrSummary" type="button" class="post__grr-line" @click="showGrrers = true">
      {{ grrSummary }}
    </button>

    <footer class="post__actions">
      <GrrButton
        :active="post.hasGrr"
        :count="post.grrCount"
        :disabled="feed.grrPending.has(post.id)"
        target="publicación"
        @toggle="feed.toggleGrr(post.id)"
      />
      <button type="button" class="post__comment-btn" @click="comments?.focus()">
        <MessageSquare aria-hidden="true" />
        Comentarios
        <span v-if="post.commentCount" class="post__count">{{ post.commentCount }}</span>
      </button>
    </footer>

    <PostComments ref="comments" :post="post" />

    <PostEditDialog v-if="isOwn" :open="editing" :post="post" @close="editing = false" />
    <ReportDialog v-if="!isOwn" :open="reporting" :post-id="post.id" @close="reporting = false" />
    <GrrersDialog v-if="showGrrers" :open="showGrrers" target-type="post" :target-id="post.id" @close="showGrrers = false" />
  </article>
</template>

<style lang="scss" scoped>
.post {
  overflow: hidden;

  &__header {
    display: flex;
    align-items: flex-start;
    gap: $space-3;
    padding: $space-3 $space-2 0 $space-4;
  }

  &__who {
    flex: 1;
    min-width: 0;
    padding-top: 0.1rem;
  }

  &__meta {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__time {
    color: inherit;
  }

  &__menu {
    margin-top: -$space-1;
  }

  &__text {
    padding: $space-2 $space-4 0;
    font-size: $fs-md;
    line-height: 1.45;
  }

  &__photo {
    @include reset-button;
    display: block;
    width: 100%;
    max-height: 36rem;
    margin-top: $space-3;
    overflow: hidden;
    background: $color-skeleton;
    cursor: zoom-in;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__grr-line {
    @include reset-button;
    display: block;
    padding: $space-2 $space-4 0;
    font-size: $fs-sm;
    color: $color-text-muted;

    &:hover {
      color: $color-grr-strong;
      text-decoration: underline;
    }
  }

  &__actions {
    display: flex;
    align-items: center;
    gap: $space-1;
    padding: $space-2 $space-3;
  }

  &__comment-btn {
    @include reset-button;
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    min-height: 2.25rem;
    padding: 0 $space-3 0 $space-2;
    border-radius: $radius;
    color: $color-text-muted;
    font-weight: 600;

    svg {
      width: 1.15rem;
      height: 1.15rem;
    }

    &:hover {
      background: $color-surface-hover;
      color: $color-text;
    }
  }

  &__count {
    font-variant-numeric: tabular-nums;
  }
}
</style>
