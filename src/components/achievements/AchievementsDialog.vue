<script setup>
import { computed } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import AchievementBadge from '@/components/achievements/AchievementBadge.vue'
import { useAchievementsStore } from '@/stores/achievements'
import { ACHIEVEMENTS, ACHIEVEMENT_TIERS, achievementLabel } from '@/config/achievements'
import { daysUntil, fullDate, toDateInput } from '@/utils/time'
import { plural } from '@/utils/text'

// Every achievement. Yours: all of them with your progress to the next level,
// and "Compartir" while you can still announce one. Someone else's: the ones
// they have earned.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  userId: { type: String, required: true },
  isSelf: { type: Boolean, default: false },
  firstName: { type: String, default: '' },
})

const emit = defineEmits(['close'])

// STORES
const achievements = useAchievementsStore()

// COMPUTED
const rows = computed(() => {
  if (props.isSelf) return achievements.mine.items
  return (achievements.byUser[props.userId]?.items ?? []).map((a) => ({ ...a, thresholds: ACHIEVEMENTS[a.code]?.thresholds ?? [1] }))
})

// METHODS
const nextStep = (row) => {
  const def = ACHIEVEMENTS[row.code]
  const next = row.thresholds[row.level]
  if (next === undefined) return row.thresholds.length > 1 ? 'Nivel máximo conseguido.' : def.describe(row.thresholds[0])
  const tier = row.thresholds.length > 1 ? `${ACHIEVEMENT_TIERS[row.level]}: ` : ''
  // Yes/no ones (a threshold of 1) have no count worth showing.
  const count = props.isSelf && next > 1 ? ` (${Math.min(row.progress, next)}/${next})` : ''
  return `${tier}${def.describe(next)}${count}`
}

const daysLeft = (row) => Math.max(0, daysUntil(toDateInput(new Date(row.shareUntil))))
</script>

<template>
  <BaseModal :open="open" :title="isSelf ? 'Tus logros' : `Logros de ${firstName}`" @close="emit('close')">
    <ul class="achievements" role="list">
      <li v-for="row in rows" :key="row.code" class="achievements__row" :class="{ 'achievements__row--pending': !row.level }">
        <AchievementBadge :code="row.code" :level="row.level" />
        <div class="achievements__text">
          <p class="achievements__name">{{ row.level ? achievementLabel(row.code, row.level) : ACHIEVEMENTS[row.code]?.name }}</p>
          <p class="achievements__hint">{{ isSelf || !row.level ? nextStep(row) : ACHIEVEMENTS[row.code]?.describe(row.thresholds[row.level - 1]) }}</p>
          <p v-if="row.earnedAt" class="achievements__hint">Conseguido el {{ fullDate(row.earnedAt) }}</p>
        </div>
        <div v-if="isSelf && row.canShare" class="achievements__share">
          <button type="button" class="btn btn--soft btn--sm" @click="achievements.share(row.code)">Compartir</button>
          <span class="achievements__hint">{{ daysLeft(row) ? `Quedan ${plural(daysLeft(row), 'día', 'días')}` : 'Último día' }}</span>
        </div>
      </li>
    </ul>
  </BaseModal>
</template>

<style lang="scss" scoped>
.achievements {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;

  &__row {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-3 0;

    & + & {
      border-top: 1px solid $color-border;
    }

    &--pending .achievements__name {
      color: $color-text-muted;
    }
  }

  &__text {
    flex: 1;
    min-width: 0;
  }

  &__name {
    font-weight: 700;
  }

  &__hint {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__share {
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    align-items: flex-end;
    gap: $space-1;
  }
}
</style>
