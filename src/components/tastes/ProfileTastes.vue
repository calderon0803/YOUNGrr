<script setup>
import { computed, markRaw, ref, watch } from 'vue'
import { Film, Music, Plus, Tv, X } from 'lucide-vue-next'
import AsyncState from '@/components/common/AsyncState.vue'
import StarRating from '@/components/tastes/StarRating.vue'
import TasteDialog from '@/components/tastes/TasteDialog.vue'
import { useTastesStore } from '@/stores/tastes'
import { useAuthStore } from '@/stores/auth'
import { useConfirm } from '@/composables/useConfirm'
import { catalogService } from '@/services/catalog.service'
import { TASTES } from '@/config/app'

// "Gustos" in a profile: music artists, films and series. Films and series
// carry their stars. Seen by whoever can see the profile; its owner adds,
// rates again and removes.

// PROPS
const props = defineProps({
  view: { type: Object, required: true },
})

// STORES
const tastes = useTastesStore()
const auth = useAuthStore()
const { confirm } = useConfirm()

// DATA
const ICONS = { artist: markRaw(Music), movie: markRaw(Film), series: markRaw(Tv) }
const dialog = ref(null)

// COMPUTED
const userId = computed(() => props.view.profile.id)
const isSelf = computed(() => userId.value === auth.meId)
const state = computed(() => tastes.lists[userId.value] ?? { status: 'loading', error: null, items: [] })
const sections = computed(() => TASTES.kinds.map((k) => ({ ...k, items: state.value.items.filter((t) => t.kind === k.key) })))

// METHODS
const remove = async (taste) => {
  const ok = await confirm({ title: 'Quitar de tus gustos', message: `«${taste.title}» dejará de aparecer en tu perfil.`, confirmLabel: 'Quitar', danger: true })
  if (ok) tastes.remove(userId.value, taste.id)
}

// WATCHERS
watch(userId, (id) => props.view.canViewProfile && tastes.load(id), { immediate: true })
</script>

<template>
  <AsyncState :status="state.status" :error="state.error" skeleton="list" @retry="tastes.load(userId)">
    <div class="tastes">
      <section v-for="section in sections" :key="section.key" class="tastes__section" :aria-labelledby="`tastes-${section.key}`">
        <div class="tastes__head">
          <h2 :id="`tastes-${section.key}`" class="tastes__title">
            <component :is="ICONS[section.key]" aria-hidden="true" />
            {{ section.label }}
            <span v-if="section.items.length" class="tastes__count">{{ section.items.length }}</span>
          </h2>
          <button v-if="isSelf" type="button" class="btn btn--secondary btn--sm" @click="dialog = { kind: section.key, taste: null }">
            <Plus aria-hidden="true" />
            {{ section.add }}
          </button>
        </div>
        <p v-if="!section.items.length" class="tastes__empty">{{ section.empty }}</p>
        <ul v-else class="tastes__list" :class="{ 'tastes__list--names': section.key === 'artist' }" role="list">
          <li v-for="taste in section.items" :key="taste.id" class="tastes__item">
            <img v-if="taste.imagePath" class="tastes__poster" :src="catalogService.imageUrl(taste.imagePath)" alt="" loading="lazy" />
            <span v-else-if="section.key !== 'artist'" class="tastes__poster tastes__poster--empty" aria-hidden="true">
              <component :is="ICONS[section.key]" />
            </span>
            <span class="tastes__text">
              <span class="tastes__name">{{ taste.title }}</span>
              <span v-if="taste.year" class="tastes__year">{{ taste.year }}</span>
              <button
                v-if="taste.rating && isSelf"
                type="button"
                class="tastes__rate"
                :aria-label="`Cambiar las estrellas de ${taste.title}`"
                @click="dialog = { kind: section.key, taste }"
              >
                <StarRating :model-value="taste.rating" size="sm" />
              </button>
              <StarRating v-else-if="taste.rating" :model-value="taste.rating" size="sm" />
            </span>
            <button v-if="isSelf" type="button" class="tastes__remove" :aria-label="`Quitar ${taste.title}`" @click="remove(taste)">
              <X aria-hidden="true" />
            </button>
          </li>
        </ul>
      </section>
    </div>
    <TasteDialog v-if="dialog" :open="!!dialog" :kind="dialog.kind" :taste="dialog.taste" @close="dialog = null" />
  </AsyncState>
</template>

<style lang="scss" scoped>
.tastes {
  display: flex;
  flex-direction: column;

  &__section {
    padding: $space-3;

    & + & {
      border-top: 1px solid $color-border;
    }
  }

  &__head {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: $space-2;
    margin-bottom: $space-2;
  }

  &__title {
    display: flex;
    align-items: center;
    gap: $space-2;
    font-size: $fs-md;
    font-weight: 700;

    svg {
      width: 1rem;
      height: 1rem;
      color: $color-text-soft;
    }
  }

  &__count {
    font-weight: 400;
    color: $color-text-soft;
  }

  &__empty {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__list {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(9rem, 1fr));
    gap: $space-3;
    margin: 0;
    padding: 0;

    &--names {
      display: flex;
      flex-wrap: wrap;
      gap: $space-2;
    }
  }

  &__item {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: $space-1;
    min-width: 0;
  }

  &__list--names &__item {
    flex-direction: row;
    align-items: center;
    padding: 0.2rem $space-1 0.2rem $space-3;
    border: 1px solid $color-border;
    border-radius: $radius-pill;
    font-size: $fs-sm;
  }

  &__poster {
    width: 100%;
    aspect-ratio: 2 / 3;
    border-radius: $radius-sm;
    object-fit: cover;

    &--empty {
      display: grid;
      place-items: center;
      background: $color-surface-alt;
      color: $color-text-soft;

      svg {
        width: 1.5rem;
        height: 1.5rem;
      }
    }
  }

  &__text {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  &__list--names &__text {
    flex-direction: row;
  }

  &__name {
    @include truncate;
    font-weight: 700;
  }

  &__year {
    font-size: $fs-xs;
    color: $color-text-muted;
  }

  &__rate {
    @include reset-button;
    align-self: flex-start;
    border-radius: $radius-sm;
  }

  &__remove {
    @include reset-button;
    display: grid;
    place-items: center;
    width: 1.5rem;
    height: 1.5rem;
    border-radius: $radius-pill;
    color: $color-text-muted;

    svg {
      width: 0.9rem;
      height: 0.9rem;
    }

    &:hover {
      background: $color-surface-hover;
      color: $color-danger;
    }
  }

  &__list:not(&__list--names) &__remove {
    position: absolute;
    top: $space-1;
    right: $space-1;
    background: $color-surface;
  }
}
</style>
