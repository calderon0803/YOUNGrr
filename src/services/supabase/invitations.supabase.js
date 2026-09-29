// Invitations with Supabase. Same interface as local/invitations.local.js.
import { rpc } from '@/services/supabase/client'
import { toSummary } from '@/services/supabase/mappers'
import { invitationLink } from '@/utils/invitations'

const toInvitation = (json) => ({
  id: json.id,
  // Only old invitations were made for an email.
  email: json.email ?? null,
  createdAt: json.created_at,
  expiresAt: json.expires_at,
  usedAt: json.used_at,
  link: json.token ? invitationLink(json.token) : null,
  usedBy: json.used_by ? toSummary(json.used_by) : null,
})

export const supabaseInvitationsService = {
  async listInvitations() {
    const data = await rpc('list_invitations', {}, 'No se han podido cargar tus invitaciones.')
    return { available: data.available, nextAt: data.next_at ?? null, items: data.invitations.map(toInvitation) }
  },

  /** A new single-use link; nothing to fill in. */
  async createInvitation() {
    return toInvitation(await rpc('create_invitation', {}, 'No se ha podido crear la invitación.'))
  },

  async cancelInvitation(invitationId) {
    await rpc('cancel_invitation', { target: invitationId }, 'No se ha podido cancelar la invitación.')
  },

  /** For the sign up page (no session needed): who invites, or null. */
  async checkInvitation(token) {
    const data = await rpc('check_invitation', { invite_token: token }, 'No se ha podido comprobar la invitación.')
    if (!data) return null
    return {
      inviter: { firstName: data.inviter.first_name, lastName: data.inviter.last_name, avatarUrl: data.inviter.avatar_url ?? null },
    }
  },
}
