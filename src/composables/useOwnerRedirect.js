import { useRouter } from 'vue-router'

/**
 * A pasted link to content the viewer may not see sends them to the owner's
 * profile instead of an error page.
 */
export const useOwnerRedirect = () => {
  const router = useRouter()

  /** @returns {boolean} true when it redirected */
  const redirectToOwner = (code, ownerId) => {
    if (code !== 'forbidden' || !ownerId) return false
    router.replace({ name: 'profile', params: { id: ownerId } })
    return true
  }

  return { redirectToOwner }
}
