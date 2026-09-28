<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Camera, MapPin, MessageCircle, Pencil } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import FriendshipButton from '@/components/friends/FriendshipButton.vue'
import { useUserStore } from '@/stores/user'
import { useMessagesStore } from '@/stores/messages'
import { useImagePicker } from '@/composables/useImagePicker'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'
import { ACCEPTED_IMAGE_TYPES } from '@/utils/image'
import { IMAGE } from '@/config/app'
import { fullName, plural } from '@/utils/text'

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

const emit = defineEmits(['edit'])

// STORES
const user = useUserStore()
const messages = useMessagesStore()
const router = useRouter()
const toast = useToast()

// DATA
const avatarInput = ref(null)
const coverInput = ref(null)
const coverFailed = ref(false)
const opening = ref(false)
const { processing, read } = useImagePicker()

// COMPUTED
const profile = computed(() => props.view.profile)
const isSelf = computed(() => props.view.friendship === 'self')
// "1.284 visitas", counted from other people's visits.
const visitsLabel = computed(() => {
  const n = props.view.visits ?? 0
  return `${new Intl.NumberFormat('es-ES', { useGrouping: 'always' }).format(n)} ${n === 1 ? 'visita' : 'visitas'}`
})
const person = computed(() => ({
  ...profile.value,
  friendship: props.view.friendship,
  canSendRequest: props.view.canSendRequest,
}))

// METHODS
const pick = async (event, field) => {
  const maxSide = field === 'avatarUrl' ? IMAGE.avatarMaxSide : IMAGE.maxSide
  const [image] = await read([...event.target.files].slice(0, 1), { maxSide })
  event.target.value = ''
  if (image) {
    coverFailed.value = false
    await user.updateImage(field, image.dataUrl)
  }
}

const sendMessage = async () => {
  opening.value = true
  try {
    const id = await messages.openWith(profile.value.id)
    router.push({ name: 'conversation', params: { id } })
  } catch (error) {
    toast.error(errorMessage(error))
  } finally {
    opening.value = false
  }
}
</script>

<template>
  <header class="profile-header panel">
    <div class="profile-header__cover">
      <img v-if="profile.coverUrl && !coverFailed" :src="profile.coverUrl" alt="" @error="coverFailed = true" />
      <template v-if="isSelf">
        <input ref="coverInput" class="visually-hidden" type="file" :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="pick($event, 'coverUrl')" />
        <button type="button" class="profile-header__cover-btn" :disabled="processing" @click="coverInput?.click()">
          <Camera aria-hidden="true" />
          Cambiar portada
        </button>
      </template>
    </div>

    <div class="profile-header__identity">
      <div class="profile-header__avatar">
        <UserAvatar :person="profile" size="xl" :decorative="false" />
        <template v-if="isSelf">
          <input ref="avatarInput" class="visually-hidden" type="file" :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="pick($event, 'avatarUrl')" />
          <button type="button" class="profile-header__avatar-btn" aria-label="Cambiar foto de perfil" :disabled="processing" @click="avatarInput?.click()">
            <Camera aria-hidden="true" />
          </button>
        </template>
      </div>

      <div class="profile-header__text">
        <h1 class="profile-header__name">{{ fullName(profile) }}</h1>
        <p class="profile-header__facts">
          <span v-if="profile.city" class="profile-header__city">
            <MapPin aria-hidden="true" />
            {{ profile.city }}
          </span>
          <span>{{ plural(view.friendsCount, 'amigo', 'amigos') }}</span>
          <span>{{ visitsLabel }}</span>
          <span v-if="!isSelf && view.mutualFriends">{{ plural(view.mutualFriends, 'en común', 'en común') }}</span>
        </p>
        <p v-if="profile.bio" class="profile-header__bio user-text">{{ profile.bio }}</p>
      </div>

      <div class="profile-header__actions">
        <button v-if="isSelf" type="button" class="btn btn--secondary" @click="emit('edit')">
          <Pencil aria-hidden="true" />
          Editar perfil
        </button>
        <template v-else>
          <FriendshipButton :person="person" />
          <button v-if="view.friendship === 'friends'" type="button" class="btn btn--secondary" :disabled="opening" @click="sendMessage">
            <MessageCircle aria-hidden="true" />
            Enviar mensaje
          </button>
        </template>
      </div>
    </div>
  </header>
</template>

<style lang="scss" scoped>
.profile-header {
  overflow: hidden;
  border-radius: 0;
  border-right: 0;
  border-left: 0;

  &__cover {
    position: relative;
    aspect-ratio: 2.4;
    background: $color-brand;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__cover-btn {
    @include reset-button;
    position: absolute;
    right: $space-3;
    bottom: $space-3;
    display: inline-flex;
    align-items: center;
    gap: $space-2;
    padding: $space-1 $space-3;
    border-radius: $radius;
    background: $color-toast-bg;
    color: $color-toast-text;
    font-size: $fs-sm;
    font-weight: 600;

    svg {
      width: 1rem;
      height: 1rem;
    }

    &:hover {
      filter: brightness(1.15);
    }
  }

  &__identity {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: $space-3;
    padding: 0 $space-4 $space-4;
    text-align: center;
  }

  &__avatar {
    position: relative;
    margin-top: -3.5rem;
    padding: 4px;
    border-radius: $radius-lg;
    background: $color-surface;
  }

  &__avatar-btn {
    @include reset-button;
    position: absolute;
    right: -0.25rem;
    bottom: -0.25rem;
    display: grid;
    place-items: center;
    width: 2.25rem;
    height: 2.25rem;
    border: 2px solid $color-surface;
    border-radius: $radius;
    background: $color-brand;
    color: $color-on-brand;

    svg {
      width: 1.1rem;
      height: 1.1rem;
    }
  }

  &__text {
    min-width: 0;
  }

  &__name {
    font-size: $fs-xl;
    font-weight: 800;
  }

  &__facts {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: $space-1 $space-3;
    margin-top: $space-1;
    color: $color-text-muted;
  }

  &__city {
    display: inline-flex;
    align-items: center;
    gap: 0.2rem;

    svg {
      width: 0.95rem;
      height: 0.95rem;
    }
  }

  &__bio {
    max-width: 36rem;
    margin-top: $space-2;
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: $space-2;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .profile-header {
    border-right: 1px solid $color-border;
    border-left: 1px solid $color-border;
    border-radius: $radius;

    &__cover {
      aspect-ratio: 3.2;
    }

    &__identity {
      flex-direction: row;
      align-items: flex-end;
      padding: 0 $space-5 $space-4;
      text-align: left;
    }

    &__avatar {
      margin-top: -4rem;
    }

    &__text {
      flex: 1;
    }

    &__facts {
      justify-content: flex-start;
    }

    &__actions {
      justify-content: flex-end;
    }
  }
}
</style>
