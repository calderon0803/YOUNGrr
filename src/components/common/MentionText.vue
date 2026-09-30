<script setup>
import { computed } from 'vue'
import { fullName } from '@/utils/text'

// A text with its "@Name Surname" mentions as links to their profiles.

// PROPS
const props = defineProps({
  text: { type: String, required: true },
  /** The people mentioned ({ id, firstName, lastName }). */
  people: { type: Array, default: () => [] },
})

// COMPUTED
const parts = computed(() => {
  const names = props.people.map((p) => ({ person: p, token: `@${fullName(p)}` })).sort((a, b) => b.token.length - a.token.length)
  if (!names.length) return [{ text: props.text }]
  const out = []
  let rest = props.text
  while (rest) {
    let found = null
    for (const n of names) {
      const at = rest.indexOf(n.token)
      if (at !== -1 && (!found || at < found.at)) found = { ...n, at }
    }
    if (!found) {
      out.push({ text: rest })
      break
    }
    if (found.at) out.push({ text: rest.slice(0, found.at) })
    out.push({ text: found.token, person: found.person })
    rest = rest.slice(found.at + found.token.length)
  }
  return out
})
</script>

<template>
  <span class="user-text"
    ><template v-for="(part, i) in parts" :key="i"
      ><RouterLink v-if="part.person" class="mention" :to="{ name: 'profile', params: { id: part.person.id } }">{{ part.text }}</RouterLink
      ><template v-else>{{ part.text }}</template></template
    ></span
  >
</template>

<style lang="scss" scoped>
.mention {
  font-weight: 700;
  color: $color-link;
}
</style>
