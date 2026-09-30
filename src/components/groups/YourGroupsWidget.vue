<script setup>
import { computed, onMounted } from 'vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useGroupsStore } from '@/stores/groups'
import { groupAvatar } from '@/utils/groups'

// "Tus grupos" in Inicio: your groups with the new posts in their Gallinero,
// the ones with news first.

// STORES
const groups = useGroupsStore()

// DATA
const SHOWN = 5

// COMPUTED
const items = computed(() =>
  groups.mine.ids
    .map((id) => groups.groups[id])
    .filter(Boolean)
    .sort((a, b) => Number(b.newPosts > 0) - Number(a.newPosts > 0)),
)
const shown = computed(() => items.value.slice(0, SHOWN))

// LIFECYCLE
onMounted(() => groups.loadMine())
</script>

<template>
  <section class="panel your-groups" aria-labelledby="your-groups-title">
    <h2 id="your-groups-title" class="panel-title">Tus grupos</h2>
    <ul v-if="shown.length" class="your-groups__list" role="list">
      <li v-for="group in shown" :key="group.id" class="your-groups__item">
        <UserAvatar :person="groupAvatar(group)" size="xs" />
        <RouterLink class="your-groups__name" :to="{ name: 'group', params: { id: group.id } }">{{ group.name }}</RouterLink>
        <span v-if="group.newPosts" class="your-groups__new">
          {{ group.newPosts }} <span class="visually-hidden">{{ group.newPosts === 1 ? 'publicación nueva' : 'publicaciones nuevas' }}</span>
        </span>
      </li>
    </ul>
    <p v-else-if="groups.mine.status === 'success'" class="your-groups__empty">Crea un grupo con tus amigos o busca uno que te interese.</p>
    <RouterLink class="your-groups__all" :to="{ name: 'groups' }">{{ items.length > SHOWN ? `Ver todos (${items.length})` : 'Ir a Grupos' }}</RouterLink>
  </section>
</template>

<style lang="scss" scoped>
.your-groups {
  &__list {
    margin: 0;
    padding: $space-2 $space-3 0;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: $space-2;
    padding: 0.2rem 0;
  }

  &__name {
    @include truncate;
    flex: 1;
    font-size: $fs-sm;
    font-weight: 700;
  }

  &__new {
    flex-shrink: 0;
    min-width: 1.25rem;
    padding: 0 $space-1;
    border-radius: $radius-pill;
    background: $color-success;
    color: $color-on-brand;
    font-size: $fs-xs;
    font-weight: 700;
    text-align: center;
  }

  &__empty {
    padding: $space-2 $space-3 0;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__all {
    display: block;
    padding: $space-2 $space-3 $space-3;
    font-size: $fs-sm;
    font-weight: 600;
  }
}
</style>
