<script setup>
import { computed, ref, watch } from 'vue'
import { Tag, X } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import DropdownMenu from '@/components/common/DropdownMenu.vue'
import GrrButton from '@/components/common/GrrButton.vue'
import GrrersDialog from '@/components/feed/GrrersDialog.vue'
import CommentItem from '@/components/feed/CommentItem.vue'
import CommentForm from '@/components/feed/CommentForm.vue'
import CoOwnerDialog from '@/components/photos/CoOwnerDialog.vue'
import { useAuthStore } from '@/stores/auth'
import { usePhotosStore } from '@/stores/photos'
import { useConfirm } from '@/composables/useConfirm'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { fullName } from '@/utils/text'
import { LIMITS } from '@/utils/validation'

// Side panel of the viewer: owners, caption, Grr, tags and comments.

// PROPS
const props = defineProps({
  photo: { type: Object, required: true },
  tagging: { type: Boolean, default: false },
  commentsLoading: { type: Boolean, default: false },
})

const emit = defineEmits(['toggle-tagging', 'highlight', 'close'])

// STORES
const auth = useAuthStore()
const photos = usePhotosStore()
const { confirm } = useConfirm()
const toast = useToast()

// DATA
const editingCaption = ref(false)
const caption = ref('')
const savingCaption = ref(false)
const showGrrers = ref(false)
const sharing = ref(false)
const answering = ref(false)

// COMPUTED
// Uploader and accepted co-owners have the same rights.
const isOwner = computed(() => !!props.photo.isOwner)
const sharedOwnership = computed(() => (props.photo.owners?.length ?? 1) > 1)
const owners = computed(() => props.photo.owners ?? [props.photo.owner])
const album = computed(() => photos.albums[props.photo.albumId])
const menuItems = computed(() => [
  { key: 'caption', label: props.photo.caption ? 'Editar pie de foto' : 'Añadir pie de foto' },
  // The album belongs to the uploader.
  ...(props.photo.isUploader && album.value?.kind === 'user' ? [{ key: 'cover', label: 'Usar como portada del álbum' }] : []),
  { key: 'share', label: 'Compartir la foto con amigos' },
  { key: 'delete', label: sharedOwnership.value ? 'Quitar de mi perfil' : 'Eliminar fotografía', danger: true },
])

// METHODS
// Any owner and the tagged person can remove a tag.
const canRemoveTag = (tag) => tag.userId === auth.meId || isOwner.value
const canDeleteComment = (comment) => comment.authorId === auth.meId || isOwner.value

const onMenu = async (key) => {
  if (key === 'caption') {
    caption.value = props.photo.caption
    editingCaption.value = true
  } else if (key === 'cover') {
    photos.setCover(props.photo.albumId, props.photo.id)
  } else if (key === 'share') {
    sharing.value = true
  } else if (key === 'delete') {
    const ok = sharedOwnership.value
      ? await confirm({ title: 'Quitar de mi perfil', message: 'Dejarás de ser dueño de la foto. Seguirá en el perfil de los otros dueños.', confirmLabel: 'Quitar', danger: true })
      : await confirm({ title: 'Eliminar fotografía', message: 'Se borrarán también sus comentarios, Grr y etiquetas.', confirmLabel: 'Eliminar', danger: true })
    if (ok) photos.deletePhoto(props.photo.id)
  }
}

const saveCaption = async () => {
  savingCaption.value = true
  try {
    await photos.updateCaption(props.photo.id, caption.value)
    editingCaption.value = false
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    savingCaption.value = false
  }
}

const answerInvite = async (accept) => {
  answering.value = true
  await photos.respondOwnerInvite(props.photo.id, accept)
  answering.value = false
}

const removeComment = async (commentId) => {
  const ok = await confirm({ title: 'Eliminar comentario', confirmLabel: 'Eliminar', danger: true })
  if (ok) photos.deleteComment(props.photo.id, commentId)
}

// WATCHERS
watch(
  () => props.photo.id,
  () => (editingCaption.value = false),
)
</script>

<template>
  <div class="details">
    <header class="details__header">
      <UserAvatar :person="photo.owner" size="md" />
      <div class="details__who">
        <p class="details__owners">
          <template v-for="(person, index) in owners" :key="person.id">
            <span v-if="index > 0">{{ index === owners.length - 1 ? ' y ' : ', ' }}</span>
            <PersonLink :person="person" @click="emit('close')" />
          </template>
        </p>
        <p class="details__meta">
          <RelativeTime :value="photo.createdAt" />
          <template v-if="photo.albumTitle && photo.albumAccessible">
            ·
            <RouterLink :to="{ name: 'album', params: { id: photo.albumId } }" @click="emit('close')">{{ photo.albumTitle }}</RouterLink>
          </template>
        </p>
      </div>
      <DropdownMenu v-if="isOwner" label="Opciones de la fotografía" :items="menuItems" @select="onMenu" />
    </header>

    <div v-if="photo.ownerInvite" class="details__invite" role="status">
      <p>
        <strong>{{ fullName(photo.ownerInvite.invitedBy) }}</strong> quiere compartir contigo esta foto. Si aceptas, también
        será tuya y saldrá en tu perfil.
      </p>
      <div class="details__invite-actions">
        <button type="button" class="btn btn--primary btn--sm" :disabled="answering" @click="answerInvite(true)">Aceptar</button>
        <button type="button" class="btn btn--secondary btn--sm" :disabled="answering" @click="answerInvite(false)">Rechazar</button>
      </div>
    </div>

    <p v-if="photo.pendingOwners?.length" class="details__hint">
      Pendiente de aceptar: {{ photo.pendingOwners.map((p) => p.firstName).join(', ') }}
    </p>

    <form v-if="editingCaption" class="details__caption-form" @submit.prevent="saveCaption">
      <label class="visually-hidden" for="caption-input">Pie de foto</label>
      <input id="caption-input" v-model="caption" class="input" :maxlength="LIMITS.caption" autofocus />
      <button type="submit" class="btn btn--primary btn--sm" :disabled="savingCaption">Guardar</button>
      <button type="button" class="btn btn--ghost btn--sm" @click="editingCaption = false">Cancelar</button>
    </form>
    <p v-else-if="photo.caption" class="details__caption user-text">{{ photo.caption }}</p>

    <div class="details__actions">
      <GrrButton :active="photo.hasGrr" :count="photo.grrCount" :disabled="photos.grrPending.has(photo.id)" target="fotografía" @toggle="photos.toggleGrr(photo.id)" />
      <button v-if="photo.grrCount" type="button" class="details__link" @click="showGrrers = true">Ver quién</button>
      <button v-if="isOwner" type="button" class="btn btn--ghost btn--sm details__tag-btn" :aria-pressed="tagging" @click="emit('toggle-tagging')">
        <Tag aria-hidden="true" />
        {{ tagging ? 'Terminar de etiquetar' : 'Etiquetar' }}
      </button>
    </div>

    <p v-if="tagging" class="details__hint" role="status">Toca o haz clic en la foto sobre la persona que quieres etiquetar.</p>

    <section v-if="photo.tags.length" class="details__tags" aria-labelledby="tags-title">
      <h3 id="tags-title" class="details__subtitle">En esta foto</h3>
      <ul class="details__tag-list" role="list">
        <li
          v-for="tag in photo.tags"
          :key="tag.id"
          class="details__tag"
          @mouseenter="emit('highlight', tag.id)"
          @mouseleave="emit('highlight', null)"
          @focusin="emit('highlight', tag.id)"
          @focusout="emit('highlight', null)"
        >
          <PersonLink :person="tag.person" @click="emit('close')" />
          <button v-if="canRemoveTag(tag)" type="button" class="details__untag" :aria-label="`Quitar etiqueta de ${fullName(tag.person)}`" @click="photos.removeTag(photo.id, tag.id)">
            <X aria-hidden="true" />
          </button>
        </li>
      </ul>
    </section>

    <section class="details__comments" aria-labelledby="photo-comments-title">
      <h3 id="photo-comments-title" class="details__subtitle">
        Comentarios<template v-if="photo.commentCount"> ({{ photo.commentCount }})</template>
      </h3>
      <p v-if="commentsLoading && !photo.comments" class="details__hint">Cargando comentarios…</p>
      <ul v-else-if="photo.comments?.length" class="details__comment-list" role="list">
        <CommentItem v-for="comment in photo.comments" :key="comment.id" :comment="comment" :can-delete="canDeleteComment(comment)" @delete="removeComment" />
      </ul>
      <p v-else class="details__hint">Nadie ha comentado todavía. Sé el primero.</p>
      <CommentForm :submit="(text) => photos.addComment(photo.id, text)" />
    </section>

    <CoOwnerDialog v-if="isOwner" :open="sharing" :photo="photo" @close="sharing = false" />
    <GrrersDialog v-if="showGrrers" :open="showGrrers" target-type="photo" :target-id="photo.id" @close="showGrrers = false" />
  </div>
</template>

<style lang="scss" scoped>
.details {
  display: flex;
  flex-direction: column;
  gap: $space-3;
  padding: $space-4;

  &__header {
    display: flex;
    align-items: flex-start;
    gap: $space-3;
  }

  &__who {
    flex: 1;
    min-width: 0;
  }

  &__owners {
    line-height: 1.3;
  }

  &__invite {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    padding: $space-3;
    border: 1px solid $color-brand-soft;
    border-radius: $radius;
    background: $color-brand-tint;
  }

  &__invite-actions {
    display: flex;
    gap: $space-2;
  }

  &__meta {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__caption {
    font-size: $fs-md;
  }

  &__caption-form {
    display: flex;
    flex-wrap: wrap;
    gap: $space-2;

    .input {
      flex: 1 1 12rem;
    }
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: $space-2;
    padding: $space-2 0;
    border-top: 1px solid $color-border;
    border-bottom: 1px solid $color-border;
  }

  &__link {
    @include reset-button;
    font-size: $fs-sm;
    color: $color-link;

    &:hover {
      text-decoration: underline;
    }
  }

  &__tag-btn {
    margin-left: auto;

    &[aria-pressed='true'] {
      background: $color-brand-tint;
      color: $color-brand-strong;
    }
  }

  &__hint {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__subtitle {
    @include section-title;
    margin-bottom: $space-1;
  }

  &__tag-list {
    display: flex;
    flex-wrap: wrap;
    gap: $space-2;
    margin: 0;
  }

  &__tag {
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    padding: 0.1rem $space-1 0.1rem $space-2;
    border: 1px solid $color-border-strong;
    border-radius: $radius-sm;
    font-size: $fs-sm;
  }

  &__untag {
    @include reset-button;
    display: grid;
    place-items: center;
    width: 1.25rem;
    height: 1.25rem;
    color: $color-text-muted;

    svg {
      width: 0.85rem;
      height: 0.85rem;
    }

    &:hover {
      color: $color-danger;
    }
  }

  &__comment-list {
    margin: 0;
  }
}
</style>
