import { computed, ref } from 'vue'
import { fullName, normalize } from '@/utils/text'

const MAX_SUGGESTIONS = 6

/**
 * "@" mentions in a text field: typing "@" and some letters suggests people
 * from `people`; picking one writes "@Name Surname " and remembers who it is.
 * `mentions` are the ids still named in the text (the database checks them again).
 * @param {import('vue').Ref<HTMLInputElement | HTMLTextAreaElement | null>} input
 * @param {import('vue').Ref<string>} text
 * @param {() => { id: string, firstName: string, lastName: string }[]} people
 */
export const useMentions = (input, text, people) => {
  const query = ref(null)
  const active = ref(0)
  const chosen = ref(new Map())
  let start = -1

  const suggestions = computed(() => {
    if (query.value === null) return []
    const q = normalize(query.value)
    return people()
      .filter((p) => normalize(fullName(p)).split(' ').some((part) => part.startsWith(q)) || normalize(fullName(p)).startsWith(q))
      .slice(0, MAX_SUGGESTIONS)
  })
  const open = computed(() => suggestions.value.length > 0)

  const mentions = computed(() => [...chosen.value].filter(([, name]) => text.value.includes(`@${name}`)).map(([id]) => id))

  const close = () => {
    query.value = null
    start = -1
  }

  /** After each keystroke: is the cursor right after "@letters"? */
  const onInput = () => {
    const el = input.value
    if (!el) return
    const before = text.value.slice(0, el.selectionStart ?? text.value.length)
    const match = /(^|\s)@([\p{L}]{0,20})$/u.exec(before)
    if (!match) return close()
    start = before.length - match[2].length - 1
    query.value = match[2]
    active.value = 0
  }

  const choose = (person) => {
    const el = input.value
    if (!el || start < 0) return
    const name = fullName(person)
    const end = el.selectionStart ?? text.value.length
    const insert = `@${name} `
    text.value = text.value.slice(0, start) + insert + text.value.slice(end)
    chosen.value = new Map(chosen.value).set(person.id, name)
    const caret = start + insert.length
    close()
    requestAnimationFrame(() => {
      el.focus()
      el.setSelectionRange(caret, caret)
    })
  }

  /** Arrows, Enter and Escape while the list is open; true when handled. */
  const onKeydown = (event) => {
    if (!open.value) return false
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault()
      const n = suggestions.value.length
      active.value = (active.value + (event.key === 'ArrowDown' ? 1 : n - 1)) % n
      return true
    }
    if (event.key === 'Enter' || event.key === 'Tab') {
      event.preventDefault()
      choose(suggestions.value[active.value])
      return true
    }
    if (event.key === 'Escape') {
      event.preventDefault()
      close()
      return true
    }
    return false
  }

  const reset = () => {
    chosen.value = new Map()
    close()
  }

  return { open, suggestions, active, mentions, onInput, onKeydown, choose, close, reset }
}
