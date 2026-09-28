// Invitations for the local demo backend. Same interface as invitations.supabase.js.
// Sign up is by invitation only: a registered user invites a friend by email
// and sends them a personal link.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { summaryOf } from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { INVITATION_DAYS, INVITATIONS_PER_USER } from '@/config/app'
import { invitationLink } from '@/utils/invitations'

const DAY_MS = 86_400_000

const isPending = (inv) => !inv.usedBy && inv.expiresAt > nowIso()

const usedCount = (db, me) => db.invitations.filter((i) => i.inviterId === me && (i.usedBy || isPending(i))).length

const view = (db, inv) => ({
  id: inv.id,
  email: inv.email,
  createdAt: inv.createdAt,
  expiresAt: inv.expiresAt,
  usedAt: inv.usedAt,
  // The link only makes sense while the invitation is pending.
  link: isPending(inv) ? invitationLink(inv.token) : null,
  usedBy: inv.usedBy ? summaryOf(db, inv.usedBy) : null,
})

/** The pending invitation for a token (and email, when signing up). */
export const findPendingInvitation = (db, token, email = null) =>
  db.invitations.find((i) => i.token === token && isPending(i) && (!email || i.email === email)) ?? null

export const localInvitationsService = {
  async listInvitations() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    return {
      available: Math.max(0, INVITATIONS_PER_USER - usedCount(db, me)),
      items: db.invitations
        .filter((i) => i.inviterId === me)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
        .map((i) => view(db, i)),
    }
  },

  /** Returns the pending invitation for that email if there is one already. */
  async createInvitation(email) {
    validate(rules.email(email))
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const address = email.trim().toLowerCase()
    ensure(
      !db.users.some((u) => u.email === address),
      'conflict',
      'Esa persona ya tiene cuenta en YOUNGrr. Búscala y envíale una solicitud de amistad.',
    )
    const existing = db.invitations.find((i) => i.inviterId === me && i.email === address && isPending(i))
    if (existing) return view(db, existing)
    ensure(usedCount(db, me) < INVITATIONS_PER_USER, 'forbidden', 'No te quedan invitaciones disponibles.')
    const createdAt = nowIso()
    const inv = {
      id: uid('inv'),
      token: `${uid('t')}${uid('t')}`.replaceAll('t_', ''),
      inviterId: me,
      email: address,
      createdAt,
      expiresAt: new Date(Date.now() + INVITATION_DAYS * DAY_MS).toISOString(),
      usedBy: null,
      usedAt: null,
    }
    db.invitations.push(inv)
    await commit()
    return view(db, inv)
  },

  /** A pending invitation can be withdrawn; it is given back. */
  async cancelInvitation(invitationId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const inv = db.invitations.find((i) => i.id === invitationId && i.inviterId === me && !i.usedBy)
    ensure(inv, 'not_found', 'Esta invitación ya no se puede cancelar.')
    db.invitations = db.invitations.filter((i) => i.id !== invitationId)
    await commit()
  },

  /** For the sign up page: who invites and to which email, or null. */
  async checkInvitation(token) {
    await latency(80, 160)
    const db = await getDb()
    const inv = findPendingInvitation(db, token)
    if (!inv) return null
    const inviter = summaryOf(db, inv.inviterId)
    return { email: inv.email, inviter }
  },
}
