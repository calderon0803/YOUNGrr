import { DEMO_ACCOUNT_IDS } from '@/data/seed'
import { commit, getDb, latency } from '@/services/local/db'
import { clearSession, getSessionUserId, setSessionUserId } from '@/services/local/session'
import { pairKey, profileOf, summaryOf } from '@/services/local/access'
import { notify } from '@/services/local/notify'
import { findPendingInvitation } from '@/services/local/invitations.local'
import { buildLocalExport, purgeLocalUser } from '@/services/local/account.local'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { NEARBY_DEFAULT_RADIUS_KM } from '@/config/app'

// Auth for the local demo backend (IndexedDB). Same interface as auth.supabase.js.

const hash = async (salt, password) => {
  const data = new TextEncoder().encode(`${salt}:${password}`)
  // crypto.subtle only exists in secure contexts (https, localhost). On a plain
  // http LAN address the local mock falls back to a non-cryptographic hash.
  if (!globalThis.crypto?.subtle) {
    let h = 2166136261
    for (const byte of data) h = Math.imul(h ^ byte, 16777619)
    return `fnv-${(h >>> 0).toString(16)}`
  }
  const digest = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('')
}

const randomSalt = () => uid('salt')

export const localAuthService = {
  /** Returns the signed-in profile, or null. */
  async getSession() {
    const db = await getDb()
    const userId = getSessionUserId()
    const profile = userId ? db.profiles.find((p) => p.id === userId) : null
    if (!profile) {
      clearSession()
      return null
    }
    return { ...profile }
  },

  async login(email, password) {
    validate(rules.email(email), rules.required(password, 'La contraseña'))
    await latency()
    const db = await getDb()
    const account = db.users.find((u) => u.email.toLowerCase() === email.trim().toLowerCase())
    const valid = account?.passwordHash && (await hash(account.salt, password)) === account.passwordHash
    ensure(valid, 'unauthorized', 'El correo o la contraseña no son correctos.')
    setSessionUserId(account.id)
    return { ...profileOf(db, account.id) }
  },

  /** Only with a pending invitation for that email. */
  async register({ firstName, lastName, email, password, location, birthDate, inviteToken }) {
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
    )
    await latency()
    const db = await getDb()
    const normalizedEmail = email.trim().toLowerCase()
    ensure(!db.users.some((u) => u.email === normalizedEmail), 'conflict', 'Ya existe una cuenta con ese correo.')
    const invitation = findPendingInvitation(db, inviteToken, normalizedEmail)
    ensure(invitation, 'forbidden', 'La invitación no es válida para ese correo o ya se ha usado.')

    const id = uid('u')
    const salt = randomSalt()
    const createdAt = nowIso()
    db.users.push({ id, email: normalizedEmail, passwordHash: await hash(salt, password), salt, createdAt })
    db.profiles.push({
      id,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      avatarUrl: null,
      coverPath: null,
      city: location?.name.trim() ?? '',
      cityLat: location?.lat ?? null,
      cityLng: location?.lng ?? null,
      // Only the confirmation is kept, not the birth date.
      adultConfirmed: true,
      bio: '',
      birthday: null,
      studies: '',
      work: '',
      createdAt,
    })
    db.settings[id] = {
      privacy: { profileVisibility: 'everyone', cityVisibility: 'friends', distanceVisibility: 'friends', friendRequests: 'everyone' },
      notifications: { grr: true, comments: true, friendRequests: true, events: true, messages: true, tags: true },
      appearance: { theme: 'system' },
      nearby: { radiusKm: NEARBY_DEFAULT_RADIUS_KM },
    }
    db.albums.push({
      id: uid('a'),
      ownerId: id,
      kind: 'wall',
      title: 'Fotos del muro',
      description: 'Fotografías publicadas en el muro.',
      coverPhotoId: null,
      createdAt,
      updatedAt: createdAt,
    })
    // Whoever invited you is your first friend.
    invitation.usedBy = id
    invitation.usedAt = createdAt
    const [userA, userB] = pairKey(invitation.inviterId, id)
    db.friendships.push({ userA, userB, createdAt })
    notify(db, { userId: invitation.inviterId, actorId: id, type: 'friend_accepted', targetId: id })
    await commit()
    setSessionUserId(id)
    return { profile: { ...profileOf(db, id) }, needsConfirmation: false }
  },

  /** Demo sign-in, only available with the local backend. */
  async loginDemo(userId) {
    ensure(DEMO_ACCOUNT_IDS.includes(userId), 'forbidden', 'Esta cuenta de demostración no está disponible.')
    await latency()
    const db = await getDb()
    setSessionUserId(userId)
    return { ...profileOf(db, userId) }
  },

  async listDemoAccounts() {
    const db = await getDb()
    return DEMO_ACCOUNT_IDS.map((id) => summaryOf(db, id))
  },

  async logout() {
    clearSession()
  },

  async changePassword(current, next) {
    validate(rules.password(next))
    await latency()
    const db = await getDb()
    const account = db.users.find((u) => u.id === getSessionUserId())
    ensure(account, 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
    if (account.passwordHash) {
      ensure((await hash(account.salt, current)) === account.passwordHash, 'validation', 'La contraseña actual no es correcta.')
    }
    account.salt = randomSalt()
    account.passwordHash = await hash(account.salt, next)
    await commit()
  },

  /** A new password without asking for the current one (first sign in, temporary password). */
  async setPassword(next) {
    validate(rules.password(next))
    await latency()
    const db = await getDb()
    const account = db.users.find((u) => u.id === getSessionUserId())
    ensure(account, 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
    account.salt = randomSalt()
    account.passwordHash = await hash(account.salt, next)
    await commit()
  },

  /** Demo backend: there are no emails; same neutral answer as with Supabase. */
  async requestPasswordReset(email) {
    validate(rules.email(email))
    await latency()
  },

  async hasRecoverySession() {
    return false
  },

  async completePasswordReset(next) {
    await this.setPassword(next)
    const db = await getDb()
    return { ...profileOf(db, getSessionUserId()) }
  },

  async changeEmail(password, nextEmail) {
    validate(rules.email(nextEmail))
    await latency()
    const db = await getDb()
    const account = db.users.find((u) => u.id === getSessionUserId())
    ensure(account, 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
    if (account.passwordHash) {
      ensure((await hash(account.salt, password)) === account.passwordHash, 'validation', 'La contraseña no es correcta.')
    }
    const address = nextEmail.trim().toLowerCase()
    // Same neutral answer when the email is taken.
    if (!db.users.some((u) => u.email === address)) account.email = address
    await commit()
  },

  async exportData() {
    const db = await getDb()
    const me = getSessionUserId()
    ensure(me, 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
    return buildLocalExport(db, me)
  },

  async deleteAccount(password) {
    await latency()
    const db = await getDb()
    const account = db.users.find((u) => u.id === getSessionUserId())
    ensure(account, 'unauthorized', 'Tu sesión ha caducado. Vuelve a entrar.')
    if (account.passwordHash) {
      ensure((await hash(account.salt, password)) === account.passwordHash, 'validation', 'La contraseña no es correcta.')
    }
    purgeLocalUser(db, account.id)
    await commit()
    clearSession()
  },

  async getEmail() {
    const db = await getDb()
    return db.users.find((u) => u.id === getSessionUserId())?.email ?? ''
  },
}
