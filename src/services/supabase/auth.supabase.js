// Auth with Supabase Auth. Same interface as local/auth.local.js.
// Sign-up metadata feeds the on_auth_user_created trigger (profile, settings,
// wall album); the own full profile is read through the my_profile() RPC.
import { ensureOnline, getSupabase, rpc, toApiError } from '@/services/supabase/client'
import { toProfile } from '@/services/supabase/mappers'
import { removeAllOwnFiles, signPhotoUrls } from '@/services/supabase/storage'
import { ApiError, ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { LEGAL } from '@/config/app'

// Supabase Auth error codes → messages for the user.
const AUTH_MESSAGES = {
  invalid_credentials: ['unauthorized', 'El correo o la contraseña no son correctos.'],
  email_not_confirmed: ['unauthorized', 'Confirma tu correo antes de entrar: te enviamos un enlace al registrarte.'],
  same_password: ['validation', 'La contraseña nueva tiene que ser distinta de la anterior.'],
  weak_password: ['validation', `La contraseña es demasiado débil. Usa al menos ${LIMITS.passwordMin} caracteres.`],
  email_address_invalid: ['validation', 'Escribe un correo electrónico válido.'],
  over_email_send_rate_limit: ['network', 'Se han enviado demasiados correos. Espera unos minutos e inténtalo de nuevo.'],
  over_request_rate_limit: ['network', 'Demasiados intentos seguidos. Espera un momento e inténtalo de nuevo.'],
  signup_disabled: ['forbidden', 'El registro de cuentas nuevas está desactivado.'],
}

// Answers that must not reveal whether an email is registered.
const NEUTRAL_EMAIL_ERRORS = ['user_already_exists', 'email_exists']

// Captured when the app loads, before Supabase reads and clears the link: a
// new password without the current one is only accepted from a recovery link,
// not from any open session.
const OPENED_FROM_RECOVERY =
  typeof window !== 'undefined' &&
  window.location.pathname === '/reset-password' &&
  (/type=recovery/.test(window.location.hash) || new URLSearchParams(window.location.search).has('code'))

/** Where the links in Supabase emails come back to (whatever domain serves the app). */
const appUrl = (path) => `${window.location.origin}${path}`

const reauthenticate = async (password) => {
  const supabase = getSupabase()
  const { data } = await supabase.auth.getUser()
  ensure(data?.user?.email, 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
  // A borrowed open session is not enough for sensitive changes.
  const check = await supabase.auth.signInWithPassword({ email: data.user.email, password })
  if (check.error) throw new ApiError('validation', 'La contraseña no es correcta.')
  return data.user
}

const authError = (error) => {
  const known = AUTH_MESSAGES[error?.code]
  return known ? new ApiError(known[0], known[1]) : toApiError(error)
}

const loadOwnProfile = async () => {
  const { data, error } = await getSupabase().rpc('my_profile')
  if (error) throw toApiError(error, 'No se ha podido cargar tu perfil.')
  ensure(data?.id, 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
  return toProfile(data)
}

export const supabaseAuthService = {
  async getSession() {
    ensureOnline()
    const { data, error } = await getSupabase().auth.getSession()
    if (error || !data.session) return null
    return loadOwnProfile()
  },

  async login(email, password) {
    validate(rules.email(email), rules.required(password, 'La contraseña'))
    ensureOnline()
    const { error } = await getSupabase().auth.signInWithPassword({ email: email.trim().toLowerCase(), password })
    if (error) throw authError(error)
    return loadOwnProfile()
  },

  /**
   * Creates the account, only with a pending invitation for that email and for
   * people aged 18 or over (both checked by the database; the birth date is
   * not stored). With email confirmation on there is no session yet.
   * @returns {Promise<{ profile: object | null, needsConfirmation: boolean }>}
   */
  async register({ firstName, lastName, email, password, location, birthDate, acceptedTerms, inviteToken }) {
    validate(
      rules.required(firstName, 'El nombre'),
      rules.max(firstName, LIMITS.name, 'El nombre'),
      rules.required(lastName, 'El apellido'),
      rules.max(lastName, LIMITS.name, 'El apellido'),
      rules.email(email),
      rules.password(password),
      rules.adult(birthDate),
      rules.optionalLocation(location),
      rules.max(location?.name, LIMITS.city, 'La ciudad'),
      inviteToken ? null : 'YOUNGrr es solo por invitación.',
      acceptedTerms ? null : 'Tienes que aceptar las condiciones de uso y la política de privacidad.',
    )
    ensureOnline()
    const { data, error } = await getSupabase().auth.signUp({
      email: email.trim().toLowerCase(),
      password,
      options: {
        emailRedirectTo: appUrl('/login'),
        data: {
          first_name: firstName.trim(),
          last_name: lastName.trim(),
          birth_date: birthDate,
          ...(location ? { city: location.name.trim(), city_lat: String(location.lat), city_lng: String(location.lng) } : {}),
          invite_token: inviteToken,
          // The database stores the version accepted (and rejects any other).
          terms_version: LEGAL.version,
        },
      },
    })
    // The database rejects sign ups without a valid invitation or under 18.
    if (error && /database error saving new user/i.test(error.message ?? '')) {
      throw new ApiError('forbidden', 'No se ha podido crear la cuenta. Comprueba tu fecha de nacimiento y que la invitación sea para este correo. Si acabas de recargar, vuelve a aceptar las condiciones.')
    }
    // An email already registered gets the same answer as a new one.
    if (error && NEUTRAL_EMAIL_ERRORS.includes(error.code)) return { profile: null, needsConfirmation: true }
    if (error) throw authError(error)
    if (!data.session) return { profile: null, needsConfirmation: true }
    return { profile: await loadOwnProfile(), needsConfirmation: false }
  },

  /** Always the same answer, whether the email exists or not. */
  async requestPasswordReset(email) {
    validate(rules.email(email))
    ensureOnline()
    const { error } = await getSupabase().auth.resetPasswordForEmail(email.trim().toLowerCase(), { redirectTo: appUrl('/reset-password') })
    // Only rate limits are worth telling; anything else looks like success.
    if (error && ['over_email_send_rate_limit', 'over_request_rate_limit'].includes(error.code)) throw authError(error)
  },

  /** True when the page was opened from a valid recovery link (and it gave a session). */
  async hasRecoverySession() {
    if (!OPENED_FROM_RECOVERY) return false
    ensureOnline()
    const { data } = await getSupabase().auth.getSession()
    return !!data.session
  },

  /** New password from the recovery link; other sessions are closed. */
  async completePasswordReset(next) {
    validate(rules.password(next))
    ensure(OPENED_FROM_RECOVERY, 'forbidden', 'Abre el enlace que te hemos enviado por correo.')
    ensureOnline()
    const supabase = getSupabase()
    const { error } = await supabase.auth.updateUser({ password: next })
    if (error) throw authError(error)
    await supabase.auth.signOut({ scope: 'others' })
    return loadOwnProfile()
  },

  /** Supabase sends a confirmation link; the email only changes once confirmed. */
  async changeEmail(password, nextEmail) {
    validate(password ? null : 'Escribe tu contraseña.', rules.email(nextEmail))
    ensureOnline()
    await reauthenticate(password)
    const { error } = await getSupabase().auth.updateUser({ email: nextEmail.trim().toLowerCase() }, { emailRedirectTo: appUrl('/settings/account') })
    if (error && !NEUTRAL_EMAIL_ERRORS.includes(error.code)) throw authError(error)
  },

  /** Everything YOUNGrr holds about you, as JSON. */
  async exportData() {
    const data = await rpc('export_my_data', {}, 'No se han podido preparar tus datos.')
    // Your photos with download links (valid for an hour).
    const urls = await signPhotoUrls(data.photos.map((p) => p.storage_path)).catch(() => ({}))
    return {
      ...data,
      photos: data.photos.map((p) => ({ ...p, download_url: urls[p.storage_path] ?? null })),
      note: 'Los enlaces de descarga de las fotos caducan una hora después de generar este archivo.',
    }
  },

  /**
   * Deletes your files from Storage (the database refuses to delete the
   * account while any remain), then the account and all its data.
   */
  async deleteAccount(password) {
    validate(password ? null : 'Escribe tu contraseña.')
    ensureOnline()
    const user = await reauthenticate(password)
    await removeAllOwnFiles(user.id)
    await rpc('delete_my_account', {}, 'No se ha podido eliminar la cuenta.')
    await getSupabase().auth.signOut({ scope: 'local' }).catch(() => {})
  },

  async loginDemo() {
    throw new ApiError('forbidden', 'Las cuentas de demostración solo existen con el backend local.')
  },

  async listDemoAccounts() {
    return []
  },

  async logout() {
    await getSupabase().auth.signOut()
  },

  async changePassword(current, next) {
    validate(rules.required(current, 'La contraseña actual'), rules.password(next))
    ensureOnline()
    await reauthenticate(current)
    const { error } = await getSupabase().auth.updateUser({ password: next })
    if (error) throw authError(error)
  },

  /** A new password without asking for the current one (first sign in, temporary password). */
  async setPassword(next) {
    validate(rules.password(next))
    ensureOnline()
    const { error } = await getSupabase().auth.updateUser({ password: next })
    if (error) throw authError(error)
  },

  async getEmail() {
    const { data } = await getSupabase().auth.getUser()
    return data?.user?.email ?? ''
  },
}
