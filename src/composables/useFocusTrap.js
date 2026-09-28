import { nextTick, onBeforeUnmount, watch } from 'vue'

const FOCUSABLE =
  'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'

/**
 * Keeps keyboard focus inside `containerRef` while `active` is true and
 * restores it to the previously focused element afterwards.
 */
export const useFocusTrap = (containerRef, active, { onEscape } = {}) => {
  let previous = null

  const onKeydown = (event) => {
    if (event.key === 'Escape' && onEscape) {
      event.stopPropagation()
      onEscape()
      return
    }
    if (event.key !== 'Tab' || !containerRef.value) return
    const items = [...containerRef.value.querySelectorAll(FOCUSABLE)].filter((el) => el.offsetParent !== null)
    if (!items.length) return
    const first = items[0]
    const last = items[items.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  const release = () => {
    document.removeEventListener('keydown', onKeydown, true)
    if (previous instanceof HTMLElement) previous.focus({ preventScroll: true })
    previous = null
  }

  watch(
    active,
    async (value) => {
      if (value) {
        previous = document.activeElement
        document.addEventListener('keydown', onKeydown, true)
        await nextTick()
        const target = containerRef.value?.querySelector('[autofocus]') ?? containerRef.value?.querySelector(FOCUSABLE)
        ;(target ?? containerRef.value)?.focus({ preventScroll: true })
      } else if (previous !== null) {
        release()
      }
    },
    { immediate: true },
  )

  onBeforeUnmount(() => {
    if (previous !== null) release()
  })
}
