import { ref } from 'vue'
import { readImageFile } from '@/utils/image'
import { useToast } from '@/composables/useToast'

/** Reads user-picked image files into resized data URLs, with feedback on errors. */
export const useImagePicker = (defaults = {}) => {
  const processing = ref(false)
  const toast = useToast()

  const read = async (files, options = {}) => {
    processing.value = true
    const results = []
    try {
      for (const file of files) {
        try {
          results.push(await readImageFile(file, { ...defaults, ...options }))
        } catch (error) {
          toast.error(error instanceof Error ? error.message : 'No se ha podido leer la imagen.')
        }
      }
    } finally {
      processing.value = false
    }
    return results
  }

  return { processing, read }
}
