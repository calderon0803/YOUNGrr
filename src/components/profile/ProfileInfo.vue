<script setup>
import { computed } from 'vue'
import { fullDate } from '@/utils/time'

// PROPS
const props = defineProps({
  profile: { type: Object, required: true },
  isSelf: { type: Boolean, default: false },
})

const emit = defineEmits(['edit'])

// COMPUTED
const birthday = computed(() => {
  if (!props.profile.birthday) return ''
  const [y, m, d] = props.profile.birthday.split('-').map(Number)
  return new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'long' }).format(new Date(y, m - 1, d))
})

const rows = computed(() =>
  [
    { label: 'Ciudad', value: props.profile.city },
    { label: 'Cumpleaños', value: birthday.value },
    { label: 'Estudios', value: props.profile.studies },
    { label: 'Trabajo', value: props.profile.work },
    { label: 'En YOUNGrr desde', value: fullDate(props.profile.createdAt) },
  ].filter((row) => row.value),
)
</script>

<template>
  <section class="info panel" aria-labelledby="info-title">
    <h2 id="info-title" class="panel-title">Información</h2>
    <div class="info__body">
      <p v-if="profile.bio" class="info__bio user-text">{{ profile.bio }}</p>
      <dl class="info__list">
        <template v-for="row in rows" :key="row.label">
          <dt>{{ row.label }}</dt>
          <dd>{{ row.value }}</dd>
        </template>
      </dl>
      <button v-if="isSelf" type="button" class="btn btn--secondary btn--sm" @click="emit('edit')">Editar información</button>
    </div>
  </section>
</template>

<style lang="scss" scoped>
.info {
  &__body {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: $space-4;
    padding: $space-4;
  }

  &__list {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: $space-2 $space-5;

    dt {
      color: $color-text-muted;
    }

    dd {
      font-weight: 600;
    }
  }
}
</style>
