<script setup>
import { computed, ref, useId, watch } from 'vue'
import AchievementBadge from '@/components/achievements/AchievementBadge.vue'
import AchievementsDialog from '@/components/achievements/AchievementsDialog.vue'
import { useAchievementsStore } from '@/stores/achievements'

// "Logros" block in the profile's left column: the earned ones as badges and
// "Ver todos" with the details (yours: also what is missing and "Compartir").

// PROPS
const props = defineProps({
  userId: { type: String, required: true },
  isSelf: { type: Boolean, default: false },
  firstName: { type: String, default: '' },
})

// STORES
const achievements = useAchievementsStore()

// DATA
const titleId = useId()
const showAll = ref(false)

// COMPUTED
const earned = computed(() => (props.isSelf ? achievements.earned : (achievements.byUser[props.userId]?.items ?? [])))

// WATCHERS
watch(
  () => props.userId,
  (id) => achievements.loadForUser(id),
  { immediate: true },
)
</script>

<template>
  <section v-if="earned.length || isSelf" class="panel achievements-block" :aria-labelledby="titleId">
    <h2 :id="titleId" class="panel-title">Logros ({{ earned.length }})</h2>
    <ul v-if="earned.length" class="achievements-block__list" role="list">
      <li v-for="a in earned.slice(0, 12)" :key="a.code">
        <AchievementBadge :code="a.code" :level="a.level" />
      </li>
    </ul>
    <p v-else class="achievements-block__empty">Todavía no tienes logros.</p>
    <button type="button" class="achievements-block__all" @click="showAll = true">Ver todos</button>
    <AchievementsDialog :open="showAll" :user-id="userId" :is-self="isSelf" :first-name="firstName" @close="showAll = false" />
  </section>
</template>

<style lang="scss" scoped>
.achievements-block {
  &__list {
    display: flex;
    flex-wrap: wrap;
    gap: $space-3 $space-2;
    margin: 0;
    padding: $space-3 $space-3 $space-2;
  }

  &__empty {
    padding: $space-2 $space-3;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__all {
    @include reset-button;
    display: block;
    padding: 0 $space-3 $space-2;
    font-size: $fs-sm;
    color: $color-link;

    &:hover {
      text-decoration: underline;
    }
  }
}
</style>
