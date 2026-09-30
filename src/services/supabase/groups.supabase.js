// Groups and their Gallinero with Supabase. Same interface as local/groups.local.js.
// Gallinero photos go to the private "photos" bucket; only the group's members read them.
import { currentUserId, rpc } from '@/services/supabase/client'
import { removePhotos, signPhotoUrls, uploadPhoto } from '@/services/supabase/storage'
import { toSummary } from '@/services/supabase/mappers'
import { validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { GROUPS } from '@/config/app'

const summaryOrNull = (json) => (json ? toSummary(json) : null)

const toGroup = (json) => ({
  id: json.id,
  // "user" (made by someone) or "place" (a town, province or community).
  kind: json.kind,
  // "closed": found by anyone, who asks to join; "secret": by invitation only.
  privacy: json.privacy,
  name: json.name,
  description: json.description ?? '',
  createdAt: json.created_at,
  owner: summaryOrNull(json.owner),
  memberCount: json.member_count ?? 0,
  // null when you are not in it.
  myRole: json.my_role ?? null,
  invitedBy: summaryOrNull(json.invited_by),
  requested: !!json.requested,
  requestCount: json.request_count ?? 0,
  newPosts: json.new_posts ?? 0,
  lastPostAt: json.last_post_at ?? null,
  // Only for its owner, while nobody else has joined.
  expiresAt: json.expires_at ?? null,
})

const toPost = (json, urls) => ({
  id: json.id,
  groupId: json.group_id,
  author: toSummary(json.author),
  text: json.text ?? '',
  photo: json.photo_path ? { url: urls[json.photo_path] ?? null, width: json.photo_width, height: json.photo_height } : null,
  createdAt: json.created_at,
  grrCount: json.grr_count ?? 0,
  hasGrr: !!json.has_grr,
  canDelete: !!json.can_delete,
  replies: (json.replies ?? []).map((r) => ({
    id: r.id,
    author: toSummary(r.author),
    text: r.text,
    createdAt: r.created_at,
    canDelete: !!r.can_delete,
  })),
})

const withPhotos = async (items) => {
  const urls = await signPhotoUrls(items.map((p) => p.photo_path))
  return items.map((p) => toPost(p, urls))
}

const one = async (json) => (await withPhotos([json]))[0]

const validateGroup = (input) =>
  validate(
    rules.required(input.name, 'El nombre del grupo'),
    rules.max(input.name, LIMITS.groupName, 'El nombre del grupo'),
    rules.max(input.description, LIMITS.groupDescription, 'La descripción'),
  )

export const supabaseGroupsService = {
  /** Your groups, the most recently active first, with their new posts. */
  async listMine() {
    return (await rpc('list_my_groups', {}, 'No se han podido cargar tus grupos.')).map(toGroup)
  },

  async invitations() {
    return (await rpc('group_invitations', {}, 'No se han podido cargar tus invitaciones.')).map(toGroup)
  },

  /** Groups deleted because nobody joined them in time. */
  async notices() {
    return (await rpc('my_group_notices', {}, 'No se han podido cargar tus avisos.')).map((n) => ({ id: n.id, groupName: n.group_name, createdAt: n.created_at }))
  },

  async dismissNotice(noticeId) {
    await rpc('dismiss_group_notice', { target: noticeId }, 'No se ha podido cerrar el aviso.')
  },

  /** Closed groups by name (secret ones never show up). */
  async search(query) {
    return (await rpc('search_groups', { q: query }, 'No se han podido buscar grupos.')).map(toGroup)
  },

  async getGroup(groupId) {
    const data = await rpc('get_group', { target: groupId }, 'No se ha podido cargar el grupo.')
    return {
      group: toGroup(data.group),
      members: data.members.map((m) => ({ person: toSummary(m.person), role: m.role, joinedAt: m.joined_at })),
      requests: data.requests.map((r) => ({ person: toSummary(r.person), createdAt: r.created_at })),
    }
  },

  async createGroup(input) {
    validateGroup(input)
    return toGroup(await rpc('create_group', { group_name: input.name, about: input.description, secret: !!input.secret }, 'No se ha podido crear el grupo.'))
  },

  async updateGroup(groupId, input) {
    validateGroup(input)
    return toGroup(
      await rpc('update_group', { target: groupId, group_name: input.name, about: input.description, secret: !!input.secret }, 'No se ha podido guardar el grupo.'),
    )
  },

  /** Only its owner. Your own Gallinero photos are deleted too. */
  async deleteGroup(groupId) {
    const paths = await rpc('delete_group', { target: groupId }, 'No se ha podido eliminar el grupo.')
    await removePhotos(paths).catch(() => {})
  },

  /** Returns how many friends were invited. */
  async invite(groupId, userIds) {
    validate(userIds.length ? null : 'Elige al menos a una persona.')
    return rpc('invite_to_group', { target: groupId, people: userIds }, 'No se ha podido enviar la invitación.')
  },

  /** The group when you accept; null when you decline. */
  async answerInvite(groupId, accept) {
    const data = await rpc('answer_group_invite', { target: groupId, accept }, 'No se ha podido guardar tu respuesta.')
    return data ? toGroup(data) : null
  },

  async requestToJoin(groupId) {
    return toGroup(await rpc('request_to_join_group', { target: groupId }, 'No se ha podido enviar la solicitud.'))
  },

  async cancelRequest(groupId) {
    const data = await rpc('cancel_group_request', { target: groupId }, 'No se ha podido retirar la solicitud.')
    return data ? toGroup(data) : null
  },

  async answerRequest(groupId, userId, accept) {
    await rpc('answer_group_request', { target: groupId, person: userId, accept }, 'No se ha podido responder a la solicitud.')
  },

  async leave(groupId) {
    await rpc('leave_group', { target: groupId }, 'No se ha podido salir del grupo.')
  },

  async removeMember(groupId, userId) {
    await rpc('remove_group_member', { target: groupId, person: userId }, 'No se ha podido quitar del grupo.')
  },

  /** 'admin', 'member' or 'owner' (hands the group over). */
  async setRole(groupId, userId, role) {
    await rpc('set_group_role', { target: groupId, person: userId, new_role: role }, 'No se ha podido cambiar el papel.')
  },

  async markSeen(groupId) {
    await rpc('mark_group_seen', { target: groupId }, 'No se ha podido actualizar el grupo.')
  },

  // ---- The Gallinero --------------------------------------------------------------------------

  /** Newest first; one extra post tells whether there are more. */
  async listPosts(groupId, { before = null } = {}) {
    const items = await rpc('list_group_posts', { target: groupId, before, page_size: GROUPS.pageSize + 1 }, 'No se ha podido cargar el Gallinero.')
    return { items: await withPhotos(items.slice(0, GROUPS.pageSize)), hasMore: items.length > GROUPS.pageSize }
  },

  /** @param {{ text: string, photo?: { dataUrl: string, width: number, height: number } | null }} input */
  async createPost(groupId, { text, photo = null }) {
    validate(rules.max(text, LIMITS.groupPost, 'La publicación'), text.trim() || photo ? null : 'Escribe algo o añade una foto.')
    const path = photo ? await uploadPhoto(await currentUserId(), photo.dataUrl) : null
    try {
      return one(
        await rpc(
          'create_group_post',
          { target: groupId, body: text, photo_path: path, photo_width: photo?.width ?? null, photo_height: photo?.height ?? null },
          'No se ha podido publicar.',
        ),
      )
    } catch (error) {
      await removePhotos([path]).catch(() => {})
      throw error
    }
  },

  async deletePost(postId) {
    const path = await rpc('delete_group_post', { target: postId }, 'No se ha podido eliminar la publicación.')
    await removePhotos([path]).catch(() => {})
  },

  async reply(postId, text) {
    validate(rules.required(text, 'La respuesta'), rules.max(text, LIMITS.groupReply, 'La respuesta'))
    return one(await rpc('add_group_reply', { target: postId, body: text }, 'No se ha podido responder.'))
  },

  async deleteReply(replyId) {
    return one(await rpc('delete_group_reply', { target: replyId }, 'No se ha podido eliminar la respuesta.'))
  },

  async setGrr(postId, value) {
    return one(await rpc('set_group_grr', { target: postId, value }, 'No se ha podido guardar tu Grr.'))
  },
}
