<script setup>
import { computed, ref } from 'vue'
import CommentItem from '@/components/feed/CommentItem.vue'
import CommentForm from '@/components/feed/CommentForm.vue'
import { useAuthStore } from '@/stores/auth'
import { useFeedStore } from '@/stores/feed'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import { errorMessage } from '@/services/errors'

// PROPS
const props = defineProps({
  post: { type: Object, required: true },
  /** Tuenti style: the comment box only opens when you click "Comentar". */
  showForm: { type: Boolean, default: true },
})

// STORES
const auth = useAuthStore()
const feed = useFeedStore()
const toast = useToast()
const { confirm } = useConfirm()

// DATA
const form = ref(null)
const loadingAll = ref(false)

// COMPUTED
const hiddenCount = computed(() => props.post.commentCount - props.post.comments.length)

// METHODS
const canDelete = (comment) => comment.authorId === auth.meId || props.post.authorId === auth.meId

const showAll = async () => {
  loadingAll.value = true
  try {
    await feed.loadAllComments(props.post.id)
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    loadingAll.value = false
  }
}

const remove = async (commentId) => {
  const ok = await confirm({ title: 'Eliminar comentario', message: 'El comentario desaparecerá para todos.', confirmLabel: 'Eliminar', danger: true })
  if (ok) feed.deleteComment(props.post.id, commentId)
}

const focus = () => requestAnimationFrame(() => form.value?.focus())

defineExpose({ focus })
</script>

<template>
  <div class="post-comments">
    <button v-if="hiddenCount > 0" type="button" class="post-comments__more" :disabled="loadingAll" @click="showAll">
      {{ loadingAll ? 'Cargando comentarios…' : `Ver ${hiddenCount === 1 ? 'el comentario anterior' : `los ${hiddenCount} comentarios anteriores`}` }}
    </button>
    <TransitionGroup v-if="post.comments.length" tag="ul" name="comment" class="post-comments__list" role="list" aria-label="Comentarios">
      <CommentItem
        v-for="comment in post.comments"
        :key="comment.id"
        :comment="comment"
        :can-delete="canDelete(comment)"
        @delete="remove"
      />
    </TransitionGroup>
    <CommentForm v-if="showForm" ref="form" :submit="(text) => feed.addComment(post.id, text)" />
  </div>
</template>

<style lang="scss" scoped>
.post-comments {
  margin-top: $space-2;
  padding: 0 $space-3 $space-2;
  background: $color-surface-alt;
  border-left: 2px solid $color-brand-soft;
  border-radius: 0 $radius-sm $radius-sm 0;

  &__more {
    @include reset-button;
    padding: $space-2 0 0;
    font-size: $fs-sm;
    font-weight: 600;
    color: $color-link;

    &:hover {
      text-decoration: underline;
    }
  }

  &__list {
    margin: 0;
    padding: 0;
  }
}

.comment-enter-active {
  transition:
    opacity $duration $ease-out,
    transform $duration $ease-out;
}

.comment-enter-from {
  opacity: 0;
  transform: translateY(-0.25rem);
}
</style>
