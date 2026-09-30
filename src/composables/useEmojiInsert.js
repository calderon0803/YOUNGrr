import { nextTick, watch } from 'vue'

/**
 * Inserts an emoji where the cursor was in an input or textarea bound to
 * `text`, without going over `max` characters, and puts the cursor right after
 * it. Picking an emoji takes the focus away, but the field keeps its selection;
 * a field never focused gets the emoji at the end.
 * @param {import('vue').Ref<HTMLInputElement | HTMLTextAreaElement | null>} input
 * @param {import('vue').Ref<string>} text
 * @param {() => number} max the field's current length limit
 */
export const useEmojiInsert = (input, text, max) => {
  let touched = false
  const onFocus = () => (touched = true)
  watch(input, (el, old) => {
    old?.removeEventListener('focus', onFocus)
    el?.addEventListener('focus', onFocus)
  })

  const insert = (emoji) => {
    const el = input.value
    const value = text.value ?? ''
    const start = touched && el ? el.selectionStart ?? value.length : value.length
    const end = touched && el ? el.selectionEnd ?? value.length : value.length
    const next = `${value.slice(0, start)}${emoji}${value.slice(end)}`
    if (next.length > max()) return
    text.value = next
    const caret = start + emoji.length
    nextTick(() => {
      el?.focus()
      el?.setSelectionRange(caret, caret)
    })
  }
  return { insert }
}
