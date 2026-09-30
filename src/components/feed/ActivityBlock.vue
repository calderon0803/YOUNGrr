<script setup>
import { computed } from 'vue'
import { Award, Images, Tag, UserPlus } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import PhotoStrip from '@/components/photos/PhotoStrip.vue'
import PostCard from '@/components/feed/PostCard.vue'
import { usePhotosStore } from '@/stores/photos'
import { useFeedStore } from '@/stores/feed'
import { formatDistance } from '@/utils/geo'
import { plural } from '@/utils/text'
import { achievementLabel } from '@/config/achievements'

// One friend in "Novedades de tus amigos", as in Tuenti: their current status
// (with its comments) on top and, apart below, what they have done lately in
// compact lines (photos uploaded, new friends, photos where they were tagged).

// PROPS
const props = defineProps({
  /** Block from the feed store: { person, statusId, uploadIds, newFriends, tagged, ... } */
  block: { type: Object, required: true },
})

// STORES
const feed = useFeedStore()
const photos = usePhotosStore()

// COMPUTED
const hasStatus = computed(() => !!props.block.statusId && !!feed.posts[props.block.statusId])
const moreFriends = computed(() => props.block.newFriendsTotal - props.block.newFriends.length)
const hasMore = computed(() => props.block.uploadIds.length > 0 || props.block.newFriends.length > 0 || props.block.tagged.length > 0 || !!props.block.achievements?.length)
// "Fotógrafo · Oro y Cuadrilla · Plata".
const achievementText = computed(() => {
  const names = (props.block.achievements ?? []).map((a) => achievementLabel(a.code, a.level))
  return names.length > 1 ? `${names.slice(0, -1).join(', ')} y ${names.at(-1)}` : (names[0] ?? '')
})

// The town; the distance only replaces it when the person hides the town.
const placeLabel = computed(() => {
  const info = props.block.nearby
  if (!info) return ''
  if (info.city) return info.city
  return info.distanceKm === null ? '' : formatDistance(info.distanceKm)
})

const profileTab = (tab) => ({ name: 'profile', params: { id: props.block.person.id }, query: { tab } })

// METHODS
const openTagged = (photoId) =>
  photos.openSingle(
    photoId,
    props.block.tagged.map((p) => p.id),
  )
</script>

<template>
  <article class="block">
    <PostCard v-if="hasStatus" :post-id="block.statusId" :nearby="block.nearby ?? null" />
    <header v-else class="block__head">
      <RouterLink class="block__avatar" :to="{ name: 'profile', params: { id: block.person.id } }" tabindex="-1" aria-hidden="true">
        <UserAvatar :person="block.person" size="md" />
      </RouterLink>
      <p class="block__who">
        <PersonLink :person="block.person" />
        <span v-if="placeLabel" class="block__place">{{ placeLabel }}</span>
      </p>
    </header>

    <section v-if="hasMore" class="block__activity" :aria-label="`Actividad de ${block.person.firstName}`">
      <h3 class="block__label" aria-hidden="true">Actividad</h3>
      <ul class="block__more" role="list">
        <li v-for="id in block.uploadIds" :key="id" class="block__row">
          <Images class="block__icon" aria-hidden="true" />
          <PostCard bare compact :post-id="id" />
        </li>

        <li v-if="block.newFriends.length" class="block__row">
          <UserPlus class="block__icon" aria-hidden="true" />
          <p class="block__text">
            {{ block.newFriendsTotal === 1 ? 'Nueva amistad con' : 'Nuevas amistades con' }}
            <template v-for="(f, i) in block.newFriends" :key="f.person.id">
              <PersonLink :person="f.person" /><template v-if="i < block.newFriends.length - 2">, </template><template v-else-if="i === block.newFriends.length - 2 && !moreFriends"> y </template>
            </template>
            <template v-if="moreFriends"> y {{ plural(moreFriends, 'persona más', 'personas más') }}</template>
            <span class="block__when"> · <RelativeTime :value="block.newFriends[0].createdAt" /></span>
          </p>
        </li>

        <li v-if="block.tagged.length" class="block__row">
          <Tag class="block__icon" aria-hidden="true" />
          <div class="block__text">
            <RouterLink :to="profileTab('tagged')">{{ plural(block.taggedTotal, 'foto etiquetada', 'fotos etiquetadas') }}</RouterLink>
            <PhotoStrip
              small
            label="Fotos en las que sale"
              :photos="block.tagged"
              :more-count="block.taggedTotal - block.tagged.length"
              :more-to="profileTab('tagged')"
              @open="openTagged"
            />
          </div>
        </li>

        <li v-if="block.achievements?.length" class="block__row">
          <Award class="block__icon" aria-hidden="true" />
          <p class="block__text">
            {{ block.achievements.length === 1 ? 'Ha conseguido el logro' : 'Ha conseguido los logros' }}
            <RouterLink :to="{ name: 'profile', params: { id: block.person.id } }">{{ achievementText }}</RouterLink>
          </p>
        </li>
      </ul>
    </section>
  </article>
</template>

<style lang="scss" scoped>
.block {
  padding-bottom: $space-1;

  &__head {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-3 $space-3 $space-1;
  }

  &__avatar {
    flex-shrink: 0;
  }

  &__who {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0 $space-2;
  }

  &__place {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  // Apart from the status, indented under the name.
  &__activity {
    margin: 0 $space-3 $space-2 calc(#{$space-3} + #{$space-3} + 2.5rem);
    padding-top: $space-2;
    border-top: 1px dashed $color-border;
  }

  &__label {
    margin-bottom: $space-1;
    font-size: $fs-xs;
    font-weight: 700;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: $color-text-muted;
  }

  &__more {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    margin: 0;
    padding: 0;
  }

  &__row {
    display: flex;
    align-items: flex-start;
    gap: $space-2;
  }

  &__icon {
    flex-shrink: 0;
    width: 0.95rem;
    height: 0.95rem;
    margin-top: 0.2rem;
    color: $color-success;
  }

  &__text {
    flex: 1;
    min-width: 0;
    line-height: 1.4;
  }

  &__when {
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
