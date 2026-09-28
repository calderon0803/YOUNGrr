<script setup>
import { computed } from 'vue'
import { Images, Tag, UserPlus } from 'lucide-vue-next'
import UserAvatar from '@/components/common/UserAvatar.vue'
import PersonLink from '@/components/common/PersonLink.vue'
import RelativeTime from '@/components/common/RelativeTime.vue'
import PhotoStrip from '@/components/photos/PhotoStrip.vue'
import PostCard from '@/components/feed/PostCard.vue'
import { usePhotosStore } from '@/stores/photos'
import { useFeedStore } from '@/stores/feed'
import { formatDistance } from '@/utils/geo'
import { plural } from '@/utils/text'

// One friend in "Novedades de tus amigos", as in Tuenti: their current status
// on top and, below, what they have done lately (photos uploaded, new friends,
// photos where they were tagged).

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
const hasMore = computed(() => props.block.uploadIds.length > 0 || props.block.newFriends.length > 0 || props.block.tagged.length > 0)

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

    <ul v-if="hasMore" class="block__more" role="list">
      <li v-for="id in block.uploadIds" :key="id" class="block__row">
        <Images class="block__icon" aria-hidden="true" />
        <PostCard bare :post-id="id" />
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
            label="Fotos en las que sale"
            :photos="block.tagged"
            :more-count="block.taggedTotal - block.tagged.length"
            :more-to="profileTab('tagged')"
            @open="openTagged"
          />
        </div>
      </li>
    </ul>
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

  // Indented under the name, like Tuenti's sub-items.
  &__more {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    margin: 0;
    padding: 0 $space-3 $space-2 calc(#{$space-3} + #{$space-3} + 2.5rem);
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
