// Invitations for the local demo backend. Same interface as invitations.supabase.js.
// Sign up is by invitation only: a registered user creates a single-use link
// and sends it to a friend, who signs up with their own email.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { summaryOf } from '@/services/local/access'
import { ensure } from '@/services/errors'
import { uid } from '@/utils/ids'
import { nowIso } from '@/utils/time'
import { INVITATION_DAYS, INVITATION_EVERY_DAYS, INVITATIONS_PER_USER } from '@/config/app'
import { invitationLink } from '@/utils/invitations'

const DAY_MS = 86_400_000

const isPending = (inv) => !inv.usedBy && inv.expiresAt > nowIso()

const usedCount = (db, me) => db.invitations.filter((i) => i.inviterId === me && (i.usedBy || isPending(i))).length

/** 1 at sign up and 1 more each week since, up to INVITATIONS_PER_USER. */
const earned = (db, me) => {
  const createdAt = Date.parse(db.profiles.find((p) => p.id === me)?.createdAt ?? nowIso())
  const weeks = Math.floor((Date.now() - createdAt) / (INVITATION_EVERY_DAYS * DAY_MS))
  return { count: Math.min(INVITATIONS_PER_USER, 1 + weeks), createdAt }
}

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

/** The pending invitation for a token. Old invitations made for an email only work with it. */
export const findPendingInvitation = (db, token, email = null) =>
  db.invitations.find((i) => i.token === token && isPending(i) && (!email || !i.email || i.email === email)) ?? null

export const localInvitationsService = {
  async listInvitations() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const { count, createdAt } = earned(db, me)
    return {
      available: Math.max(0, count - usedCount(db, me)),
      nextAt: count < INVITATIONS_PER_USER ? new Date(createdAt + count * INVITATION_EVERY_DAYS * DAY_MS).toISOString() : null,
      items: db.invitations
        .filter((i) => i.inviterId === me)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
        .map((i) => view(db, i)),
    }
  },

  /** A new single-use link; nothing to fill in. */
  async createInvitation() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(usedCount(db, me) < earned(db, me).count, 'forbidden', 'No te quedan invitaciones disponibles.')
    const createdAt = nowIso()
    const inv = {
      id: uid('inv'),
      token: `${uid('t')}${uid('t')}`.replaceAll('t_', ''),
      inviterId: me,
      email: null,
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

  /** For the sign up page: who invites, or null. */
  async checkInvitation(token) {
    await latency(80, 160)
    const db = await getDb()
    const inv = findPendingInvitation(db, token)
    if (!inv) return null
    const inviter = summaryOf(db, inv.inviterId)
    return { inviter }
  },
}
