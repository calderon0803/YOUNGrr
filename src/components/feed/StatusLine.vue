<script setup>
import { computed, ref, watch } from 'vue'
import { Pencil } from 'lucide-vue-next'
import RelativeTime from '@/components/common/RelativeTime.vue'
import EmojiPicker from '@/components/common/EmojiPicker.vue'
import { useFeedStore } from '@/stores/feed'
import { useUserStore } from '@/stores/user'
import { useAuthStore } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useEmojiInsert } from '@/composables/useEmojiInsert'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'

// Your status on the home page, in one line, as in Tuenti: the field shows
// your current status; write a new one and press Enter to replace it. Leaving
// it empty removes it.

// STORES
const feed = useFeedStore()
const user = useUserStore()
const auth = useAuthStore()
const toast = useToast()

// DATA
const text = ref('')
const saving = ref(false)
const input = ref(null)
const { insert: addEmoji } = useEmojiInsert(input, text, () => LIMITS.status)

// COMPUTED
const current = computed(() => user.profiles[auth.meId]?.data?.status ?? null)
const dirty = computed(() => text.value.trim() !== (current.value?.text ?? ''))
const remaining = computed(() => LIMITS.status - text.value.length)

// METHODS
const setProfileStatus = (status) => {
  const view = user.profiles[auth.meId]?.data
  if (view) view.status = status
}

const save = async () => {
  if (!dirty.value || saving.value || remaining.value < 0) return
  saving.value = true
  try {
    if (text.value.trim()) {
      const post = await feed.setStatus(text.value)
      setProfileStatus({ postId: post.id, text: post.text, createdAt: post.createdAt })
    } else if (current.value && (await feed.deletePost(current.value.postId))) {
      setProfileStatus(null)
    }
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    saving.value = false
  }
}

const cancel = (event) => {
  text.value = current.value?.text ?? ''
  event.target.blur()
}

// WATCHERS
watch(current, (status) => (text.value = status?.text ?? ''), { immediate: true })
</script>

<template>
  <form class="status-line" @submit.prevent="save">
    <label class="visually-hidden" for="status-line-input">Tu estado</label>
    <div class="status-line__field">
      <input
        id="status-line-input"
        ref="input"
        v-model="text"
        class="status-line__input"
        type="text"
        placeholder="¿Qué estás haciendo?"
        autocomplete="off"
        enterkeyhint="done"
        :maxlength="LIMITS.status"
        :disabled="saving"
        @keydown.esc="cancel"
      />
      <Pencil class="status-line__pencil" aria-hidden="true" />
    </div>
    <EmojiPicker :disabled="saving" @pick="addEmoji" />
    <span v-if="dirty && remaining < 30" class="status-line__count" aria-live="polite">{{ remaining }}</span>
    <button v-if="dirty" type="submit" class="btn btn--primary btn--sm" :disabled="saving">
      {{ saving ? 'Guardando…' : text.trim() ? 'Guardar' : 'Borrar estado' }}
    </button>
    <span v-else-if="current" class="status-line__when"><RelativeTime :value="current.createdAt" /></span>
  </form>
</template>

<style lang="scss" scoped>
.status-line {
  display: flex;
  align-items: center;
  gap: $space-2;
  padding: $space-2 $space-3;
  border-bottom: 1px solid $color-border;

  &__field {
    position: relative;
    flex: 1;
    min-width: 0;
  }

  &__input {
    width: 100%;
    height: 2rem;
    padding: 0 1.75rem 0 $space-2;
    border: 1px solid $color-border-strong;
    border-radius: $radius-sm;
    background: $color-surface;
    color: $color-text;
    font-size: $fs-base;

    &:focus-visible {
      outline: 2px solid $color-focus;
      outline-offset: -1px;
    }
  }

  &__pencil {
    position: absolute;
    top: 50%;
    right: 0.5rem;
    width: 0.85rem;
    height: 0.85rem;
    color: $color-text-muted;
    transform: translateY(-50%);
    pointer-events: none;
  }

  &__count,
  &__when {
    flex-shrink: 0;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
