<script setup>
import { computed, ref } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import LevelBadge from '@/components/levels/LevelBadge.vue'
import { useXpStore } from '@/stores/xp'
import { XP_MATURE_DAYS, XP_RULES } from '@/config/levels'

// Your level in your box in Inicio: only you see the progress, the experience
// on its way (published in the last days) and how it is earned.

// STORES
const xp = useXpStore()

// DATA
const explaining = ref(false)

// COMPUTED
const mine = computed(() => xp.mine)
const toPercent = (amount) => {
  const span = mine.value.nextLevelXp - mine.value.levelXp
  return span > 0 ? Math.min(100, Math.max(0, Math.round((amount / span) * 100))) : 100
}
const percent = computed(() => (mine.value ? toPercent(mine.value.xp - mine.value.levelXp) : 0))
// What is on its way, in a lighter tone after the progress (up to the end of the bar).
const pendingPercent = computed(() => (mine.value ? Math.min(100 - percent.value, toPercent(mine.value.pending)) : 0))
</script>

<template>
  <div v-if="mine" class="level">
    <p class="level__line">
      <LevelBadge :level="mine.level" />
      <span class="level__numbers">{{ mine.xp }} / {{ mine.nextLevelXp }} XP</span>
      <button type="button" class="level__help" @click="explaining = true">¿Cómo se gana?</button>
    </p>
    <div
      class="level__bar"
      role="progressbar"
      :aria-valuenow="percent"
      aria-valuemin="0"
      aria-valuemax="100"
      :aria-valuetext="mine.pending ? `${percent} %, y ${mine.pending} XP en camino` : `${percent} %`"
      :aria-label="`Progreso hasta el nivel ${mine.level + 1}`"
    >
      <span class="level__fill" :style="{ width: `${percent}%` }" />
      <span v-if="pendingPercent" class="level__pending" :style="{ width: `${pendingPercent}%` }" />
    </div>
    <p v-if="mine.streak > 1" class="level__extra">{{ mine.streak }} días seguidos</p>

    <BaseModal :open="explaining" title="Cómo se gana experiencia" @close="explaining = false">
      <div class="level-help">
        <p>
          Lo que publicas cuenta si sigue publicado {{ XP_MATURE_DAYS }} días después: mientras tanto se ve en la barra en un tono más claro.
          La experiencia ganada no se pierde nunca, aunque luego borres algo.
        </p>
        <table class="level-help__table">
          <thead>
            <tr><th scope="col">Qué</th><th scope="col">XP</th><th scope="col">Límite</th></tr>
          </thead>
          <tbody>
            <tr v-for="rule in XP_RULES" :key="rule.label">
              <td>{{ rule.label }}</td>
              <td>{{ rule.points }}</td>
              <td>{{ rule.limit }}</td>
            </tr>
          </tbody>
        </table>
        <p class="level-help__note">Cada cosa cuenta una vez. Algunos niveles tienen su propio logro.</p>
      </div>
    </BaseModal>
  </div>
</template>

<style lang="scss" scoped>
.level {
  display: flex;
  flex-direction: column;
  gap: $space-1;
  padding: 0 $space-3 $space-2;

  &__line {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: $space-1 $space-2;
    font-size: $fs-sm;
  }

  &__numbers {
    color: $color-text-muted;
  }

  &__help {
    @include reset-button;
    margin-left: auto;
    color: $color-link;
    font-size: $fs-xs;

    &:hover {
      text-decoration: underline;
    }
  }

  &__bar {
    display: flex;
    height: 0.625rem;
    overflow: hidden;
    border: 1px solid $color-border-strong;
    border-radius: $radius-pill;
    background: $color-border;
  }

  &__fill,
  &__pending {
    height: 100%;
    background: $color-brand;
  }

  &__pending {
    opacity: 0.5;
  }

  &__extra {
    font-size: $fs-xs;
    color: $color-text-muted;
  }
}

.level-help {
  display: flex;
  flex-direction: column;
  gap: $space-3;
  font-size: $fs-sm;

  &__table {
    width: 100%;
    border-collapse: collapse;

    th,
    td {
      padding: $space-1 $space-2;
      border-bottom: 1px solid $color-border;
      text-align: left;
      vertical-align: top;
    }

    td:nth-child(2) {
      white-space: nowrap;
    }
  }

  &__note {
    color: $color-text-muted;
  }
}
</style>
