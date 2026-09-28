/**
 * Error returned by the service layer. `code` is stable for the UI, `message`
 * is already written for the user.
 * @typedef {'validation' | 'unauthorized' | 'forbidden' | 'not_found' | 'conflict' | 'network' | 'not_available'} ApiErrorCode
 */
export class ApiError extends Error {
  /**
   * @param {ApiErrorCode} code
   * @param {{ ownerId?: string }} [details] e.g. whose content was not accessible
   */
  constructor(code, message, details = {}) {
    super(message)
    this.name = 'ApiError'
    this.code = code
    this.details = details
  }
}

export const fail = (code, message) => {
  throw new ApiError(code, message)
}

/** Content the viewer may not see: the UI sends them to the owner's profile. */
export const ensureAccess = (condition, ownerId) => {
  if (!condition) throw new ApiError('forbidden', 'No tienes acceso a este contenido.', { ownerId })
}

export const ensure = (condition, code, message) => {
  if (!condition) fail(code, message)
}

/** Validation helper: throws the first error message, if any. */
export const validate = (...checks) => {
  const error = checks.find(Boolean)
  if (error) fail('validation', error)
}

export const errorMessage = (error, fallback = 'Algo ha fallado. Inténtalo de nuevo.') => {
  if (error instanceof ApiError) return error.message
  if (error instanceof Error && error.message) return error.message
  return fallback
}
