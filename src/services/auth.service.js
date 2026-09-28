import { DEMO_ACCOUNT_IDS } from '@/data/seed'
import { commit, getDb, latency } from '@/services/local/db'
import { clearSession, getSessionUserId, setSessionUserId } from '@/services/local/session'
import { profileOf, summaryOf } from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { DATA_SOURCE, NEARBY_DEFAULT_RADIUS_KM } from '@/config/app'

export const isLocalBackend = DATA_SOURCE === 'local'

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

export const authService = {
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

  async register({ firstName, lastName, email, password, location }) {
    validate(
      rules.required(firstName, 'El nombre'),
      rules.max(firstName, LIMITS.name, 'El nombre'),
      rules.required(lastName, 'El apellido'),
      rules.max(lastName, LIMITS.name, 'El apellido'),
      rules.email(email),
      rules.password(password),
      rules.location(location),
      rules.max(location?.name, LIMITS.city, 'La ciudad'),
    )
    await latency()
    const db = await getDb()
    const normalizedEmail = email.trim().toLowerCase()
    ensure(!db.users.some((u) => u.email === normalizedEmail), 'conflict', 'Ya existe una cuenta con ese correo.')

    const id = uid('u')
    const salt = randomSalt()
    const createdAt = nowIso()
    db.users.push({ id, email: normalizedEmail, passwordHash: await hash(salt, password), salt, createdAt })
    db.profiles.push({
      id,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      avatarUrl: null,
      coverUrl: null,
      city: location.name.trim(),
      cityLat: location.lat,
      cityLng: location.lng,
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
    await commit()
    setSessionUserId(id)
    return { ...profileOf(db, id) }
  },

  /** Demo sign-in, only available with the local backend. */
  async loginDemo(userId) {
    ensure(isLocalBackend && DEMO_ACCOUNT_IDS.includes(userId), 'forbidden', 'Esta cuenta de demostración no está disponible.')
    await latency()
    const db = await getDb()
    setSessionUserId(userId)
    return { ...profileOf(db, userId) }
  },

  async listDemoAccounts() {
    if (!isLocalBackend) return []
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

  async getEmail() {
    const db = await getDb()
    return db.users.find((u) => u.id === getSessionUserId())?.email ?? ''
  },
}
