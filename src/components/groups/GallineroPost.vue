<script setup>
import { computed, nextTick, ref } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import GrrButton from '@/components/common/GrrButton.vue'
import CommentForm from '@/components/feed/CommentForm.vue'
import MentionText from '@/components/common/MentionText.vue'
import ReportDialog from '@/components/feed/ReportDialog.vue'
import { useAuthStore } from '@/stores/auth'
import { useGroupsStore } from '@/stores/groups'
import { useConfirm } from '@/composables/useConfirm'
import { fullName } from '@/utils/text'
import { LIMITS } from '@/utils/validation'

// A post in the Gallinero: who, the text and photo, Grr and the replies below.
// Its author or the group's administrators delete it; anyone else reports it.

// PROPS
const props = defineProps({
  postId: { type: String, required: true },
})

// STORES
const auth = useAuthStore()
const groups = useGroupsStore()
const { confirm } = useConfirm()

// DATA
const replying = ref(false)
const replyForm = ref(null)
const reporting = ref(null)
const grrBusy = ref(false)

// COMPUTED
const post = computed(() => groups.posts[props.postId])
const isOwn = computed(() => post.value?.author.id === auth.meId)
const menu = computed(() => [
  ...(post.value?.canDelete ? [{ key: 'delete', label: 'Eliminar', danger: true }] : []),
  ...(!isOwn.value ? [{ key: 'report', label: 'Reportar', danger: true }] : []),
])
const titleId = computed(() => `gallinero-${props.postId}`)
// Who can be mentioned in a reply: the people of the group.
const people = computed(() => (groups.details[post.value?.groupId]?.members ?? []).map((m) => m.person).filter((p) => p.id !== auth.meId))

// METHODS
const onMenu = async (key) => {
  if (key === 'report') reporting.value = { kind: 'group_post', id: props.postId }
  else if (key === 'delete') {
    const ok = await confirm({
      title: 'Eliminar la publicación',
      message: 'Se eliminarán también sus respuestas y Grr. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    })
    if (ok) groups.deletePost(props.postId)
  }
}

const replyMenu = (reply) => [
  ...(reply.canDelete ? [{ key: 'delete', label: 'Eliminar', danger: true }] : []),
  ...(reply.author.id !== auth.meId ? [{ key: 'report', label: 'Reportar', danger: true }] : []),
]

const onReplyMenu = async (reply, key) => {
  if (key === 'report') reporting.value = { kind: 'group_reply', id: reply.id }
  else if (key === 'delete') {
    const ok = await confirm({ title: 'Eliminar la respuesta', message: 'No se puede deshacer.', confirmLabel: 'Eliminar', danger: true })
    if (ok) groups.deleteReply(props.postId, reply.id)
  }
}

const reply = async () => {
  replying.value = true
  await nextTick()
  replyForm.value?.focus()
}

const toggleGrr = async () => {
  grrBusy.value = true
  await groups.toggleGrr(props.postId)
  grrBusy.value = false
}
</script>

<template>
  <article v-if="post" class="gallinero-post" :aria-labelledby="titleId">
    <RouterLink class="gallinero-post__avatar" :to="{ name: 'profile', params: { id: post.author.id } }" tabindex="-1" aria-hidden="true">
      <UserAvatar :person="post.author" size="md" />
    </RouterLink>

    <div class="gallinero-post__body">
      <p :id="titleId" class="gallinero-post__line">
        <PersonLink :person="post.author" />
        <MentionText v-if="post.text" :text="post.text" :people="post.mentions" />
      </p>
      <img
        v-if="post.photo?.url"
        class="gallinero-post__photo"
        :src="post.photo.url"
        :width="post.photo.width"
        :height="post.photo.height"
        :alt="`Foto de ${fullName(post.author)}`"
        loading="lazy"
      />

      <p class="gallinero-post__meta">
        <RelativeTime :value="post.createdAt" />
        <span class="gallinero-post__sep">
          <GrrButton compact :active="post.hasGrr" :count="post.grrCount" :disabled="grrBusy" target="esta publicación" @toggle="toggleGrr" />
        </span>
        <span class="gallinero-post__sep">
          <button type="button" class="gallinero-post__link" :aria-expanded="replying" @click="reply">
            Responder<template v-if="post.replies.length"> ({{ post.replies.length }})</template>
          </button>
        </span>
      </p>

      <ul v-if="post.replies.length" class="gallinero-post__replies" role="list">
        <li v-for="item in post.replies" :key="item.id" class="gallinero-post__reply">
          <UserAvatar :person="item.author" size="sm" />
          <p class="gallinero-post__reply-text">
            <PersonLink :person="item.author" />
            <MentionText :text="item.text" :people="item.mentions ?? []" />
            <span class="gallinero-post__reply-time"><RelativeTime :value="item.createdAt" /></span>
          </p>
          <DropdownMenu
            v-if="replyMenu(item).length"
            class="gallinero-post__menu"
            :label="`Opciones de la respuesta de ${fullName(item.author)}`"
            :items="replyMenu(item)"
            @select="(key) => onReplyMenu(item, key)"
          />
        </li>
      </ul>

      <CommentForm
        v-if="replying"
        ref="replyForm"
        :max="LIMITS.groupReply"
        placeholder="Escribe una respuesta..."
        :people="people"
        :submit="(text, mentions) => groups.reply(postId, text, mentions)"
      />
    </div>

    <DropdownMenu
      v-if="menu.length"
      class="gallinero-post__menu"
      :label="`Opciones de la publicación de ${fullName(post.author)}`"
      :items="menu"
      @select="onMenu"
    />

    <ReportDialog v-if="reporting" :open="!!reporting" :kind="reporting.kind" :target-id="reporting.id" @close="reporting = null" />
  </article>
</template>

<style lang="scss" scoped>
.gallinero-post {
  display: flex;
  align-items: flex-start;
  gap: $space-3;
  padding: $space-3;

  & + & {
    border-top: 1px solid $color-border;
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
    overflow-wrap: anywhere;

    :deep(.person-link) {
      margin-right: 0.35rem;
    }
  }

  &__photo {
    display: block;
    width: auto;
    max-width: 100%;
    height: auto;
    max-height: 22rem;
    margin-top: $space-2;
    border-radius: $radius-sm;
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

  &__replies {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    margin: $space-2 0 0;
    padding: $space-2;
    border-radius: $radius-sm;
    background: $color-surface-alt;
  }

  &__reply {
    display: flex;
    align-items: flex-start;
    gap: $space-2;
  }

  &__reply-text {
    flex: 1;
    min-width: 0;
    font-size: $fs-sm;
    overflow-wrap: anywhere;

    :deep(.person-link) {
      margin-right: 0.35rem;
    }
  }

  &__reply-time {
    margin-left: $space-1;
    color: $color-text-muted;
    font-size: $fs-xs;
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
