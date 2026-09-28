// Auth with Supabase Auth. Same interface as local/auth.local.js.
// Sign-up metadata feeds the on_auth_user_created trigger (profile, settings,
// wall album); the own full profile is read through the my_profile() RPC.
import { ensureOnline, getSupabase, toApiError } from '@/services/supabase/client'
import { toProfile } from '@/services/supabase/mappers'
import { ApiError, ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'

// Supabase Auth error codes → messages for the user.
const AUTH_MESSAGES = {
  invalid_credentials: ['unauthorized', 'El correo o la contraseña no son correctos.'],
  email_not_confirmed: ['unauthorized', 'Confirma tu correo antes de entrar: te enviamos un enlace al registrarte.'],
  user_already_exists: ['conflict', 'Ya existe una cuenta con ese correo.'],
  email_exists: ['conflict', 'Ya existe una cuenta con ese correo.'],
  weak_password: ['validation', `La contraseña es demasiado débil. Usa al menos ${LIMITS.passwordMin} caracteres.`],
  email_address_invalid: ['validation', 'Escribe un correo electrónico válido.'],
  over_email_send_rate_limit: ['network', 'Se han enviado demasiados correos. Espera unos minutos e inténtalo de nuevo.'],
  over_request_rate_limit: ['network', 'Demasiados intentos seguidos. Espera un momento e inténtalo de nuevo.'],
  signup_disabled: ['forbidden', 'El registro de cuentas nuevas está desactivado.'],
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
   * Creates the account. With email confirmation enabled in Supabase there is
   * no session yet: the user has to open the link sent by email first.
   * @returns {Promise<{ profile: object | null, needsConfirmation: boolean }>}
   */
  /** Only with a pending invitation for that email (checked by the database). */
  async register({ firstName, lastName, email, password, location, inviteToken }) {
    validate(
      rules.required(firstName, 'El nombre'),
      rules.max(firstName, LIMITS.name, 'El nombre'),
      rules.required(lastName, 'El apellido'),
      rules.max(lastName, LIMITS.name, 'El apellido'),
      rules.email(email),
      rules.password(password),
      rules.location(location),
      rules.max(location?.name, LIMITS.city, 'La ciudad'),
      inviteToken ? null : 'YOUNGrr es solo por invitación.',
    )
    ensureOnline()
    const { data, error } = await getSupabase().auth.signUp({
      email: email.trim().toLowerCase(),
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/login`,
        data: {
          first_name: firstName.trim(),
          last_name: lastName.trim(),
          city: location.name.trim(),
          city_lat: String(location.lat),
          city_lng: String(location.lng),
          invite_token: inviteToken,
        },
      },
    })
    // The database rejects sign ups without a valid invitation for that email.
    if (error && /database error saving new user/i.test(error.message ?? '')) {
      throw new ApiError('forbidden', 'La invitación no es válida para ese correo o ya se ha usado.')
    }
    if (error) throw authError(error)
    // With confirmation on, an existing email comes back as a user without identities.
    if (data.user && data.user.identities?.length === 0) throw new ApiError('conflict', 'Ya existe una cuenta con ese correo.')
    if (!data.session) return { profile: null, needsConfirmation: true }
    return { profile: await loadOwnProfile(), needsConfirmation: false }
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
    const supabase = getSupabase()
    const { data } = await supabase.auth.getUser()
    ensure(data?.user?.email, 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
    // Re-authenticate so a borrowed open session cannot change the password.
    const check = await supabase.auth.signInWithPassword({ email: data.user.email, password: current })
    if (check.error) throw new ApiError('validation', 'La contraseña actual no es correcta.')
    const { error } = await supabase.auth.updateUser({ password: next })
    if (error) throw authError(error)
  },

  async getEmail() {
    const { data } = await getSupabase().auth.getUser()
    return data?.user?.email ?? ''
  },
}
