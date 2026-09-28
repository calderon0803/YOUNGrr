import { onBeforeUnmount, ref } from 'vue'

/** Reactive `matchMedia`: true while the query matches. */
export const useMediaQuery = (query) => {
  const media = window.matchMedia(query)
  const matches = ref(media.matches)
  const onChange = (event) => (matches.value = event.matches)
  media.addEventListener('change', onChange)
  onBeforeUnmount(() => media.removeEventListener('change', onChange))
  return matches
}
