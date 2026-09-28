import { IMAGE } from '@/config/app'

export const ACCEPTED_IMAGE_TYPES = IMAGE.acceptedTypes.join(',')

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error('No se ha podido leer la imagen.'))
    img.src = src
  })

/**
 * Validates an image file and returns a resized JPEG data URL, so photos stay
 * light enough for local storage (and for upload once there is a backend).
 * @param {File} file
 * @returns {Promise<{ dataUrl: string, width: number, height: number }>}
 */
export const readImageFile = async (file, { maxSide = IMAGE.maxSide, quality = IMAGE.quality } = {}) => {
  if (!IMAGE.acceptedTypes.includes(file.type)) {
    throw new Error('Formato no admitido. Usa JPG, PNG, WebP o GIF.')
  }
  if (file.size > IMAGE.maxBytes) {
    throw new Error('La imagen pesa demasiado (máximo 20 MB).')
  }

  const objectUrl = URL.createObjectURL(file)
  try {
    const img = await loadImage(objectUrl)
    const scale = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight))
    const width = Math.round(img.naturalWidth * scale)
    const height = Math.round(img.naturalHeight * scale)

    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height
    const ctx = canvas.getContext('2d')
    if (!ctx) throw new Error('No se ha podido procesar la imagen.')
    ctx.drawImage(img, 0, 0, width, height)

    return { dataUrl: canvas.toDataURL('image/jpeg', quality), width, height }
  } finally {
    URL.revokeObjectURL(objectUrl)
  }
}
