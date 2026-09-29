import { IMAGE_CHECK } from '@/config/app'

// Automatic image check before uploading, in the browser: the photo never
// leaves the device for it. NSFWJS (open model, MobileNetV2 mid) tells nudity
// and sexual content apart from normal photos. It only runs on this app, so it
// is a first filter: reports and moderation stay for the rest.

let modelPromise = null

/** Loads TensorFlow.js and the model once, the first time an image is checked. */
const loadModel = () => {
  modelPromise ??= (async () => {
    const [tf, { load }, { MobileNetV2MidModel }] = await Promise.all([
      import('@tensorflow/tfjs'),
      import('nsfwjs/core'),
      import('nsfwjs/models/mobilenet_v2_mid'),
    ])
    tf.enableProdMode()
    return load('MobileNetV2Mid', { modelDefinitions: [MobileNetV2MidModel] })
  })().catch((error) => {
    modelPromise = null
    throw error
  })
  return modelPromise
}

/**
 * @param {HTMLCanvasElement} canvas the image, already decoded
 * @returns {Promise<boolean>} false when it looks explicit
 * @throws {Error} when the check cannot run (old device, no WebGL, download
 *   failed): nothing is uploaded without it
 */
export const isImageAllowed = async (canvas) => {
  let predictions
  try {
    predictions = await (await loadModel()).classify(canvas)
  } catch (error) {
    console.warn('No se ha podido comprobar la imagen automáticamente.', error)
    throw new Error('No se ha podido comprobar la imagen, así que no se puede subir. Revisa tu conexión y vuelve a intentarlo, o prueba con otro navegador.')
  }
  const score = Object.fromEntries(predictions.map((p) => [p.className, p.probability]))
  const explicit = (score.Porn ?? 0) + (score.Hentai ?? 0)
  return explicit < IMAGE_CHECK.explicit && (score.Sexy ?? 0) < IMAGE_CHECK.suggestive
}
