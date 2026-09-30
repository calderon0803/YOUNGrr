<script setup>
import { onMounted, useId } from 'vue'
import AchievementBadge from '@/components/achievements/AchievementBadge.vue'
import { useAchievementsStore } from '@/stores/achievements'
import { achievementLabel } from '@/config/achievements'
import { fullDate } from '@/utils/time'

// Inicio: achievements you earned lately and can still announce to your
// friends. Loading them also checks for new ones.

// STORES
const achievements = useAchievementsStore()

// DATA
const titleId = useId()

// LIFECYCLE
onMounted(() => achievements.loadMine())
</script>

<template>
  <section v-if="achievements.toShare.length" class="panel to-share" :aria-labelledby="titleId">
    <h2 :id="titleId" class="panel-title">{{ achievements.toShare.length === 1 ? 'Nuevo logro' : 'Nuevos logros' }}</h2>
    <ul class="to-share__list" role="list">
      <li v-for="a in achievements.toShare" :key="a.code" class="to-share__item">
        <AchievementBadge :code="a.code" :level="a.level" size="sm" />
        <span class="to-share__text">
          <span class="to-share__name">{{ achievementLabel(a.code, a.level) }}</span>
          <span class="to-share__until">Compártelo hasta el {{ fullDate(a.shareUntil) }}</span>
        </span>
        <button type="button" class="btn btn--soft btn--sm" @click="achievements.share(a.code)">Compartir</button>
      </li>
    </ul>
  </section>
</template>

<style lang="scss" scoped>
.to-share {
  &__list {
    margin: 0;
    padding: $space-2 $space-3;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: $space-2;
    padding: $space-1 0;
  }

  &__text {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
  }

  &__name {
    @include truncate;
    font-size: $fs-sm;
    font-weight: 700;
  }

  &__until {
    font-size: $fs-xs;
    color: $color-text-muted;
  }
}
</style>
