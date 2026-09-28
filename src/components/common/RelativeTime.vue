<script setup>
import { computed } from 'vue'
import { useNow } from '@/composables/useNow'
import { fullDate, clockTime, relativeTime } from '@/utils/time'

// PROPS
const props = defineProps({
  value: { type: String, required: true },
})

// DATA
const now = useNow()

// COMPUTED
const label = computed(() => relativeTime(props.value, now.value))
const title = computed(() => `${fullDate(props.value)}, ${clockTime(props.value)}`)
</script>

<template>
  <time :datetime="value" :title="title">{{ label }}</time>
</template>
