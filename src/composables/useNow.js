import { onScopeDispose, ref } from 'vue'

// One shared ticking clock so every "Hace 5 minutos" stays current.
const now = ref(Date.now())
let subscribers = 0
let timer = null

export const useNow = () => {
  subscribers += 1
  if (!timer) timer = setInterval(() => (now.value = Date.now()), 30_000)

  onScopeDispose(() => {
    subscribers -= 1
    if (subscribers === 0 && timer) {
      clearInterval(timer)
      timer = null
    }
  })
  return now
}
