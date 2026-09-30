<script setup>
import { computed, onMounted, ref, useId } from 'vue'
import { useRouter } from 'vue-router'
import { Camera, MessageCircle, Pencil } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import FriendshipButton from '@/components/friends/FriendshipButton.vue'
import ReportDialog from '@/components/feed/ReportDialog.vue'
import ProfileAchievements from '@/components/achievements/ProfileAchievements.vue'
import { useUserStore } from '@/stores/user'
import { useMessagesStore } from '@/stores/messages'
import { useFriendsStore } from '@/stores/friends'
import { useImagePicker } from '@/composables/useImagePicker'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import { errorMessage } from '@/services/errors'
import { ACCEPTED_IMAGE_TYPES } from '@/utils/image'
import { IMAGE } from '@/config/app'
import { fullDate } from '@/utils/time'
import { fullName, plural } from '@/utils/text'

// Tuenti-style profile sidebar: big picture, actions, details and friends.

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

const emit = defineEmits(['edit'])

// STORES
const user = useUserStore()
const messages = useMessagesStore()
const friends = useFriendsStore()
const router = useRouter()
const toast = useToast()

// DATA
const avatarInput = ref(null)
const opening = ref(false)
const reporting = ref(false)
const { confirm } = useConfirm()
const infoId = useId()
const friendsId = useId()
const { processing, read } = useImagePicker()
const dayMonth = new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'long' })

// COMPUTED
const profile = computed(() => props.view.profile)
const isSelf = computed(() => props.view.friendship === 'self')
const person = computed(() => ({ ...profile.value, friendship: props.view.friendship, canSendRequest: props.view.canSendRequest }))
const friendList = computed(() => friends.lists[profile.value.id]?.items ?? [])

// Day and month only: other people never get the year.
const birthday = computed(() => {
  if (!profile.value.birthdayDay) return ''
  const [m, d] = profile.value.birthdayDay.split('-').map(Number)
  return dayMonth.format(new Date(2000, m - 1, d))
})

const details = computed(() =>
  [
    { label: 'Ciudad', value: profile.value.city },
    { label: 'Cumpleaños', value: birthday.value },
    { label: 'Estudios', value: profile.value.studies },
    { label: 'Trabajo', value: profile.value.work },
    { label: 'En YOUNGrr desde', value: fullDate(profile.value.createdAt) },
  ].filter((row) => row.value),
)

// METHODS
const pickAvatar = async (event) => {
  const [image] = await read([...event.target.files].slice(0, 1), { maxSide: IMAGE.avatarMaxSide })
  event.target.value = ''
  if (image) await user.updateImage('avatarUrl', image.dataUrl)
}

// Blocking works both ways and removes the friendship; the other person is not told.
const block = async () => {
  const ok = await confirm({
    title: `Bloquear a ${fullName(profile.value)}`,
    message: 'Dejaréis de ser amigos y no podréis veros el contenido, escribiros ni enviaros solicitudes. No se le avisa. Puedes desbloquear cuando quieras.',
    confirmLabel: 'Bloquear',
    danger: true,
  })
  if (ok) await friends.block(profile.value)
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

// LIFECYCLE
onMounted(() => {
  if (props.view.canViewProfile) friends.loadFriends(profile.value.id)
})
</script>

<template>
  <aside class="aside" aria-label="Datos del perfil">
    <div class="aside__picture panel">
      <div class="aside__avatar">
        <UserAvatar :person="profile" size="xxl" :decorative="false" />
        <template v-if="isSelf">
          <input ref="avatarInput" class="visually-hidden" type="file" :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="pickAvatar" />
          <button type="button" class="aside__avatar-btn" :disabled="processing" @click="avatarInput?.click()">
            <Camera aria-hidden="true" />
            Cambiar foto
          </button>
        </template>
      </div>

      <div class="aside__actions">
        <button v-if="isSelf" type="button" class="btn btn--secondary btn--sm btn--block" @click="emit('edit')">
          <Pencil aria-hidden="true" />
          Editar perfil
        </button>
        <template v-else>
          <FriendshipButton v-if="!friends.isBlocked(profile.id)" :person="person" size="sm" />
          <button v-if="view.friendship === 'friends'" type="button" class="btn btn--secondary btn--sm" :disabled="opening" @click="sendMessage">
            <MessageCircle aria-hidden="true" />
            Enviar mensaje
          </button>
          <button type="button" class="aside__report" @click="reporting = true">Reportar perfil</button>
          <button v-if="friends.isBlocked(profile.id)" type="button" class="aside__report" @click="friends.unblock(profile)">Desbloquear</button>
          <button v-else type="button" class="aside__report" @click="block">Bloquear</button>
          <ReportDialog :open="reporting" kind="profile" :target-id="profile.id" @close="reporting = false" />
        </template>
      </div>
    </div>

    <section v-if="view.canViewProfile" class="panel aside__block" :aria-labelledby="infoId">
      <h2 :id="infoId" class="panel-title">Información</h2>
      <div class="aside__info">
        <p v-if="profile.bio" class="aside__bio user-text">{{ profile.bio }}</p>
        <dl class="aside__details">
          <template v-for="row in details" :key="row.label">
            <dt>{{ row.label }}</dt>
            <dd>{{ row.value }}</dd>
          </template>
        </dl>
      </div>
    </section>

    <section v-if="view.canViewProfile" class="panel aside__block" :aria-labelledby="friendsId">
      <h2 :id="friendsId" class="panel-title">
        Amigos ({{ view.friendsCount }})<template v-if="!isSelf && view.mutualFriends"> · {{ plural(view.mutualFriends, 'en común', 'en común') }}</template>
      </h2>
      <ul v-if="friendList.length" class="aside__friends" role="list">
        <li v-for="friend in friendList.slice(0, 9)" :key="friend.id">
          <RouterLink class="aside__friend" :to="{ name: 'profile', params: { id: friend.id } }" :title="fullName(friend)">
            <UserAvatar :person="friend" size="lg" />
            <span class="aside__friend-name">{{ friend.firstName }}</span>
          </RouterLink>
        </li>
      </ul>
      <p v-else class="aside__empty">{{ isSelf ? 'Todavía no tienes amigos.' : 'Todavía no tiene amigos.' }}</p>
      <RouterLink v-if="view.friendsCount > 9" class="aside__all" :to="{ query: { tab: 'friends' } }">Ver todos</RouterLink>
    </section>

    <ProfileAchievements v-if="view.canViewProfile" class="aside__block" :user-id="profile.id" :is-self="isSelf" :first-name="profile.firstName" />
  </aside>
</template>

<style lang="scss" scoped>
// On mobile the sidebar's blocks join the page flow, so the name, status and
// wall come right after the picture (see ProfilePage).
.aside {
  display: contents;

  &__block {
    order: 3;
  }

  &__picture {
    order: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: $space-3;
    padding: $space-3;
  }

  &__avatar {
    position: relative;
  }

  &__avatar-btn {
    @include reset-button;
    position: absolute;
    right: $space-2;
    bottom: $space-2;
    display: inline-flex;
    align-items: center;
    gap: $space-1;
    padding: 0.2rem $space-2;
    border-radius: $radius-sm;
    background: $color-toast-bg;
    color: $color-toast-text;
    font-size: $fs-xs;
    font-weight: 600;

    svg {
      width: 0.85rem;
      height: 0.85rem;
    }
  }

  &__actions {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: $space-2;
    width: 100%;
  }

  &__report {
    @include reset-button;
    width: 100%;
    font-size: $fs-xs;
    color: $color-text-muted;

    &:hover {
      color: $color-danger;
      text-decoration: underline;
    }
  }

  &__info {
    display: flex;
    flex-direction: column;
    gap: $space-3;
    padding: $space-3;
  }

  &__details {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: $space-1 $space-3;
    font-size: $fs-sm;

    dt {
      color: $color-text-muted;
    }

    dd {
      margin: 0;
      font-weight: 600;
      overflow-wrap: anywhere;
    }
  }

  &__friends {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: $space-2;
    margin: 0;
    padding: $space-3;
  }

  &__friend {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.15rem;
    color: $color-link;
    font-size: $fs-xs;

    &:hover {
      text-decoration: none;

      .aside__friend-name {
        text-decoration: underline;
      }
    }
  }

  &__friend-name {
    @include truncate;
    max-width: 100%;
  }

  &__empty {
    padding: $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__all {
    display: block;
    padding: 0 $space-3 $space-3;
    font-size: $fs-sm;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .aside {
    display: flex;
    flex-direction: column;
    gap: $space-3;
  }
}
</style>
