// Groups and their Gallinero for the local demo backend. Same interface as
// groups.supabase.js and the same rules as the groups migration:
// - closed groups are found by anyone (who asks to join); secret ones only by
//   their members and invited people;
// - the owner names administrators; administrators accept requests, edit the
//   group, remove members and delete posts;
// - members invite their friends; up to GROUPS.maxMembers people;
// - blocks hide posts and replies between the two people.
// Place groups (communities, provinces and towns) are joined directly and have no
// owner: the moderators in them administer them. A town's group is created when
// PLACE_GROUPS.threshold people have asked for it.
import { commit, getDb, latency } from '@/services/local/db'
import { requireUserId } from '@/services/local/session'
import { areFriends, groupMemberCount, groupRole, isBlockedBetween, isGroupAdmin, isGroupMember, profileOf, summaryOf } from '@/services/local/access'
import { ensure, validate } from '@/services/errors'
import { LIMITS, rules } from '@/utils/validation'
import { uid } from '@/utils/ids'
import { normalize } from '@/utils/text'
import { nowIso } from '@/utils/time'
import { GROUPS, PLACE_GROUPS } from '@/config/app'
import { placeParentKey } from '@/utils/places'

const DAY_MS = 86_400_000
const ROLE_ORDER = { owner: 0, admin: 1, member: 2 }

const ownerOf = (db, groupId) => db.groupMembers.find((m) => m.groupId === groupId && m.role === 'owner')?.userId ?? null

const invitationOf = (db, groupId, userId) => db.groupInvites.find((i) => i.groupId === groupId && i.userId === userId)

/** Same as can_see_group(): members, invited people, and everyone for closed groups (without a block with the owner). */
const canSeeGroup = (db, me, group) => {
  if (isGroupMember(db, group.id, me) || invitationOf(db, group.id, me)) return true
  const owner = ownerOf(db, group.id)
  return group.privacy === 'closed' && !(owner && isBlockedBetween(db, me, owner))
}

const visiblePost = (db, me) => (p) => p.authorId === me || !isBlockedBetween(db, me, p.authorId)

const newPostsFor = (db, me, groupId) => {
  const member = db.groupMembers.find((m) => m.groupId === groupId && m.userId === me)
  if (!member) return 0
  return db.groupPosts.filter((p) => p.groupId === groupId && p.authorId !== me && p.createdAt > member.lastSeenAt && visiblePost(db, me)(p)).length
}

const groupView = (db, me, group) => {
  const role = groupRole(db, group.id, me)
  const owner = ownerOf(db, group.id)
  const invite = invitationOf(db, group.id, me)
  const posts = db.groupPosts.filter((p) => p.groupId === group.id)
  return {
    id: group.id,
    kind: group.kind,
    privacy: group.privacy,
    name: group.name,
    description: group.description,
    createdAt: group.createdAt,
    placeLevel: group.placeLevel ?? null,
    parent: parentOf(db, group),
    canManage: isGroupAdmin(db, group.id, me),
    owner: owner ? summaryOf(db, owner) : null,
    memberCount: groupMemberCount(db, group.id),
    myRole: role,
    invitedBy: invite ? summaryOf(db, invite.invitedBy) : null,
    requested: db.groupJoinRequests.some((r) => r.groupId === group.id && r.userId === me),
    requestCount: isGroupAdmin(db, group.id, me) ? db.groupJoinRequests.filter((r) => r.groupId === group.id).length : 0,
    newPosts: newPostsFor(db, me, group.id),
    lastPostAt: role ? (posts.map((p) => p.createdAt).sort().at(-1) ?? null) : null,
    expiresAt:
      role === 'owner' && group.kind === 'user' && !group.firstJoinedAt ? new Date(Date.parse(group.createdAt) + GROUPS.emptyDays * DAY_MS).toISOString() : null,
  }
}

const visibleGroup = (db, me, groupId) => {
  const group = db.groups.find((g) => g.id === groupId)
  ensure(group && canSeeGroup(db, me, group), 'not_found', 'Este grupo no existe o no puedes verlo.')
  return group
}

const memberGroup = (db, me, groupId) => {
  const group = visibleGroup(db, me, groupId)
  ensure(isGroupMember(db, groupId, me), 'forbidden', 'Solo las personas del grupo pueden hacer esto.')
  return group
}

const adminGroup = (db, me, groupId) => {
  const group = memberGroup(db, me, groupId)
  ensure(isGroupAdmin(db, groupId, me), 'forbidden', 'Solo quien administra el grupo puede hacer esto.')
  return group
}

const validateGroup = (input) =>
  validate(
    rules.required(input.name, 'El nombre del grupo'),
    rules.max(input.name, LIMITS.groupName, 'El nombre del grupo'),
    rules.max(input.description, LIMITS.groupDescription, 'La descripción'),
  )

const join = (db, group, userId) => {
  if (isGroupMember(db, group.id, userId)) return
  ensure(group.kind === 'place' || groupMemberCount(db, group.id) < GROUPS.maxMembers, 'conflict', `Este grupo ya tiene ${GROUPS.maxMembers} personas, el máximo.`)
  const now = nowIso()
  db.groupMembers.push({ groupId: group.id, userId, role: 'member', joinedAt: now, lastSeenAt: now })
  if (!group.firstJoinedAt && group.createdBy !== userId) group.firstJoinedAt = now
  db.groupInvites = db.groupInvites.filter((i) => !(i.groupId === group.id && i.userId === userId))
  db.groupJoinRequests = db.groupJoinRequests.filter((r) => !(r.groupId === group.id && r.userId === userId))
}

const removeGroup = (db, groupId) => {
  const postIds = new Set(db.groupPosts.filter((p) => p.groupId === groupId).map((p) => p.id))
  db.groups = db.groups.filter((g) => g.id !== groupId)
  db.groupMembers = db.groupMembers.filter((m) => m.groupId !== groupId)
  db.groupInvites = db.groupInvites.filter((i) => i.groupId !== groupId)
  db.groupJoinRequests = db.groupJoinRequests.filter((r) => r.groupId !== groupId)
  db.groupPosts = db.groupPosts.filter((p) => !postIds.has(p.id))
  db.groupReplies = db.groupReplies.filter((r) => !postIds.has(r.postId))
  db.groupPostGrrs = db.groupPostGrrs.filter((g) => !postIds.has(g.postId))
  const eventIds = new Set(db.events.filter((e) => e.groupId === groupId).map((e) => e.id))
  db.events = db.events.filter((e) => !eventIds.has(e.id))
  db.eventMembers = db.eventMembers.filter((m) => !eventIds.has(m.eventId))
}

/** The owner's role goes to the oldest administrator (or member); an empty group goes. */
export const leaveGroup = (db, person, groupId) => {
  const was = groupRole(db, groupId, person)
  if (!was) return
  db.groupMembers = db.groupMembers.filter((m) => !(m.groupId === groupId && m.userId === person))
  // A place group stays even when everyone leaves.
  if (db.groups.find((g) => g.id === groupId)?.kind === 'place') return
  const rest = db.groupMembers.filter((m) => m.groupId === groupId)
  if (!rest.length) return removeGroup(db, groupId)
  if (was === 'owner') {
    const heir = [...rest].sort((a, b) => (a.role === 'admin' ? 0 : 1) - (b.role === 'admin' ? 0 : 1) || a.joinedAt.localeCompare(b.joinedAt))[0]
    heir.role = 'owner'
  }
}

/** Groups nobody joined in GROUPS.emptyDays go, and their creator gets a notice (the nightly job). */
const cleanUpEmptyGroups = (db) => {
  const requestsLimit = new Date(Date.now() - PLACE_GROUPS.requestDays * DAY_MS).toISOString()
  db.placeRequests = db.placeRequests.filter((r) => r.createdAt > requestsLimit)
  const limit = new Date(Date.now() - GROUPS.emptyDays * DAY_MS).toISOString()
  for (const group of db.groups.filter((g) => g.kind === 'user' && !g.firstJoinedAt && g.createdAt < limit)) {
    if (group.createdBy) db.groupNotices.push({ id: uid('gn'), kind: 'expired', groupId: null, userId: group.createdBy, groupName: group.name, createdAt: nowIso() })
    removeGroup(db, group.id)
  }
}

const parentOf = (db, group) => {
  const parent = group.parentId ? db.groups.find((g) => g.id === group.parentId) : null
  return parent ? { id: parent.id, name: parent.name } : null
}

const placeStatusOf = (db, me, key) => {
  const group = db.groups.find((g) => g.placeKey === key)
  const requests = db.placeRequests.filter((r) => r.placeKey === key)
  return {
    group: group ? groupView(db, me, group) : null,
    count: requests.length,
    threshold: PLACE_GROUPS.threshold,
    requested: requests.some((r) => r.userId === me),
  }
}

const postView = (db, me, post) => {
  const grrs = db.groupPostGrrs.filter((g) => g.postId === post.id)
  const admin = isGroupAdmin(db, post.groupId, me)
  return {
    id: post.id,
    groupId: post.groupId,
    author: summaryOf(db, post.authorId),
    text: post.text,
    photo: post.photoUrl ? { url: post.photoUrl, width: post.photoWidth, height: post.photoHeight } : null,
    createdAt: post.createdAt,
    grrCount: grrs.length,
    hasGrr: grrs.some((g) => g.userId === me),
    canDelete: post.authorId === me || admin,
    replies: db.groupReplies
      .filter((r) => r.postId === post.id && visiblePost(db, me)(r))
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
      .map((r) => ({ id: r.id, author: summaryOf(db, r.authorId), text: r.text, createdAt: r.createdAt, canDelete: r.authorId === me || admin })),
  }
}

const visibleGroupPost = (db, me, postId) => {
  const post = db.groupPosts.find((p) => p.id === postId)
  ensure(post && isGroupMember(db, post.groupId, me) && visiblePost(db, me)(post), 'not_found', 'Esta publicación ya no existe.')
  return post
}

export const localGroupsService = {
  async listMine() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    cleanUpEmptyGroups(db)
    const active = (g) => {
      const joined = db.groupMembers.find((m) => m.groupId === g.id && m.userId === me).joinedAt
      const last = db.groupPosts.filter((p) => p.groupId === g.id).map((p) => p.createdAt).sort().at(-1)
      return last && last > joined ? last : joined
    }
    return db.groups
      .filter((g) => isGroupMember(db, g.id, me))
      .sort((a, b) => active(b).localeCompare(active(a)))
      .map((g) => groupView(db, me, g))
  },

  async invitations() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    return db.groupInvites
      .filter((i) => i.userId === me && !isBlockedBetween(db, me, i.invitedBy))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map((i) => groupView(db, me, db.groups.find((g) => g.id === i.groupId)))
  },

  async notices() {
    const db = await getDb()
    const me = requireUserId(db)
    return db.groupNotices
      .filter((n) => n.userId === me)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map(({ id, kind, groupId, groupName, createdAt }) => ({ id, kind: kind ?? 'expired', groupId: groupId ?? null, groupName, createdAt }))
  },

  async dismissNotice(noticeId) {
    const db = await getDb()
    const me = requireUserId(db)
    db.groupNotices = db.groupNotices.filter((n) => !(n.id === noticeId && n.userId === me))
    await commit()
  },

  async search(query) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const q = query.trim().toLocaleLowerCase('es')
    if (!q) return []
    return db.groups
      .filter((g) => (g.privacy === 'closed' || isGroupMember(db, g.id, me)) && canSeeGroup(db, me, g))
      .filter((g) => `${g.name} ${g.description}`.toLocaleLowerCase('es').includes(q))
      .sort((a, b) => groupMemberCount(db, b.id) - groupMemberCount(db, a.id) || a.name.localeCompare(b.name))
      .slice(0, 20)
      .map((g) => groupView(db, me, g))
  },

  async getGroup(groupId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const group = visibleGroup(db, me, groupId)
    const inside = isGroupMember(db, groupId, me)
    return {
      group: groupView(db, me, group),
      members: inside
        ? db.groupMembers
            .filter((m) => m.groupId === groupId && (m.userId === me || !isBlockedBetween(db, me, m.userId)))
            .filter((m) => group.kind === 'user' || m.userId === me || m.role !== 'member' || areFriends(db, me, m.userId))
            .sort((a, b) => ROLE_ORDER[a.role] - ROLE_ORDER[b.role] || a.joinedAt.localeCompare(b.joinedAt))
            .map((m) => ({ person: summaryOf(db, m.userId), role: m.role, joinedAt: m.joinedAt }))
        : [],
      requests: isGroupAdmin(db, groupId, me)
        ? db.groupJoinRequests
            .filter((r) => r.groupId === groupId && !isBlockedBetween(db, me, r.userId))
            .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
            .map((r) => ({ person: summaryOf(db, r.userId), createdAt: r.createdAt }))
        : [],
    }
  },

  async createGroup(input) {
    validateGroup(input)
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(
      db.groups.filter((g) => g.createdBy === me && g.kind === 'user').length < GROUPS.maxCreated,
      'conflict',
      `Ya has creado ${GROUPS.maxCreated} grupos, el máximo. Elimina alguno para crear otro.`,
    )
    const now = nowIso()
    const group = {
      id: uid('g'),
      kind: 'user',
      privacy: input.secret ? 'secret' : 'closed',
      name: input.name.trim(),
      description: (input.description ?? '').trim(),
      createdBy: me,
      createdAt: now,
      updatedAt: now,
      firstJoinedAt: null,
    }
    db.groups.push(group)
    db.groupMembers.push({ groupId: group.id, userId: me, role: 'owner', joinedAt: now, lastSeenAt: now })
    await commit()
    return groupView(db, me, group)
  },

  async updateGroup(groupId, input) {
    validateGroup(input)
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const group = adminGroup(db, me, groupId)
    Object.assign(group, {
      name: group.kind === 'user' ? input.name.trim() : group.name,
      description: (input.description ?? '').trim(),
      privacy: group.kind === 'user' ? (input.secret ? 'secret' : 'closed') : group.privacy,
      updatedAt: nowIso(),
    })
    await commit()
    return groupView(db, me, group)
  },

  async deleteGroup(groupId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    memberGroup(db, me, groupId)
    ensure(groupRole(db, groupId, me) === 'owner', 'forbidden', 'Solo quien es propietario del grupo puede eliminarlo.')
    removeGroup(db, groupId)
    await commit()
  },

  async invite(groupId, userIds) {
    validate(userIds.length ? null : 'Elige al menos a una persona.')
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const group = memberGroup(db, me, groupId)
    let fresh = 0
    for (const id of [...new Set(userIds)].filter((x) => x !== me)) {
      if (isGroupMember(db, groupId, id) || invitationOf(db, groupId, id)) continue
      ensure(areFriends(db, me, id) && !isBlockedBetween(db, me, id), 'forbidden', 'Solo puedes invitar a tus amigos.')
      // Someone who asked to join and is invited by an administrator is simply in.
      if (db.groupJoinRequests.some((r) => r.groupId === groupId && r.userId === id) && isGroupAdmin(db, groupId, me)) join(db, group, id)
      else db.groupInvites.push({ groupId, userId: id, invitedBy: me, createdAt: nowIso() })
      fresh += 1
    }
    await commit()
    return fresh
  },

  async answerInvite(groupId, accept) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(invitationOf(db, groupId, me), 'not_found', 'Esta invitación ya no existe.')
    const group = db.groups.find((g) => g.id === groupId)
    if (accept) join(db, group, me)
    else db.groupInvites = db.groupInvites.filter((i) => !(i.groupId === groupId && i.userId === me))
    await commit()
    return accept ? groupView(db, me, group) : null
  },

  async requestToJoin(groupId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const group = visibleGroup(db, me, groupId)
    if (!isGroupMember(db, groupId, me)) {
      if (group.kind === 'place' || invitationOf(db, groupId, me)) join(db, group, me)
      else {
        ensure(group.privacy === 'closed', 'forbidden', 'A este grupo solo se entra con invitación.')
        if (!db.groupJoinRequests.some((r) => r.groupId === groupId && r.userId === me)) db.groupJoinRequests.push({ groupId, userId: me, createdAt: nowIso() })
      }
    }
    await commit()
    return groupView(db, me, group)
  },

  async cancelRequest(groupId) {
    await latency(60, 140)
    const db = await getDb()
    const me = requireUserId(db)
    db.groupJoinRequests = db.groupJoinRequests.filter((r) => !(r.groupId === groupId && r.userId === me))
    await commit()
    const group = db.groups.find((g) => g.id === groupId)
    return group && canSeeGroup(db, me, group) ? groupView(db, me, group) : null
  },

  async answerRequest(groupId, userId, accept) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const group = adminGroup(db, me, groupId)
    ensure(db.groupJoinRequests.some((r) => r.groupId === groupId && r.userId === userId), 'not_found', 'Esta solicitud ya no existe.')
    if (accept) join(db, group, userId)
    else db.groupJoinRequests = db.groupJoinRequests.filter((r) => !(r.groupId === groupId && r.userId === userId))
    await commit()
  },

  async leave(groupId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    ensure(isGroupMember(db, groupId, me), 'not_found', 'No formas parte de este grupo.')
    leaveGroup(db, me, groupId)
    await commit()
  },

  async removeMember(groupId, userId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    adminGroup(db, me, groupId)
    ensure(userId !== me, 'validation', 'Para irte, sal del grupo.')
    const theirs = groupRole(db, groupId, userId)
    ensure(theirs, 'not_found', 'Esta persona ya no está en el grupo.')
    const group = db.groups.find((g) => g.id === groupId)
    const canRemoveAdmins = groupRole(db, groupId, me) === 'owner' || (group.kind === 'place' && db.moderators.includes(me))
    ensure(theirs === 'member' || (theirs === 'admin' && canRemoveAdmins), 'forbidden', 'No puedes quitar a esta persona.')
    db.groupMembers = db.groupMembers.filter((m) => !(m.groupId === groupId && m.userId === userId))
    await commit()
  },

  async setRole(groupId, userId, role) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const group = memberGroup(db, me, groupId)
    if (group.kind === 'place') {
      ensure(db.moderators.includes(me), 'forbidden', 'Los grupos de lugares los administra la moderación de YOUNGrr.')
      validate(['admin', 'member'].includes(role) ? null : 'Papel no válido.')
    } else {
      ensure(groupRole(db, groupId, me) === 'owner', 'forbidden', 'Solo quien es propietario del grupo puede cambiar los papeles.')
      validate(['owner', 'admin', 'member'].includes(role) ? null : 'Papel no válido.')
    }
    const member = db.groupMembers.find((m) => m.groupId === groupId && m.userId === userId)
    ensure(member && userId !== me, 'validation', 'Elige a otra persona del grupo.')
    if (role === 'owner') db.groupMembers.find((m) => m.groupId === groupId && m.userId === me).role = 'admin'
    member.role = role
    await commit()
  },

  async markSeen(groupId) {
    const db = await getDb()
    const me = requireUserId(db)
    const member = db.groupMembers.find((m) => m.groupId === groupId && m.userId === me)
    if (member) {
      member.lastSeenAt = nowIso()
      await commit()
    }
  },

  // ---- Place groups ---------------------------------------------------------------------------

  async listPlaces(parentId = null) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const LEVEL = { province: 0, municipality: 1 }
    return db.groups
      .filter((g) => g.kind === 'place' && (parentId ? g.parentId === parentId : !g.parentId && g.placeLevel === 'community'))
      .sort((a, b) => (LEVEL[a.placeLevel] ?? 0) - (LEVEL[b.placeLevel] ?? 0) || a.name.localeCompare(b.name, 'es'))
      .map((g) => groupView(db, me, g))
  },

  async suggestPlaces() {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const city = normalize(profileOf(db, me).city ?? '')
    if (!city) return []
    const chain = []
    for (const town of db.groups.filter((g) => g.placeLevel === 'municipality' && normalize(g.name) === city)) {
      for (let g = town; g && !chain.includes(g); g = db.groups.find((x) => x.id === g.parentId)) chain.push(g)
    }
    return chain.map((g) => groupView(db, me, g))
  },

  async placeStatus(key) {
    const db = await getDb()
    const me = requireUserId(db)
    return placeStatusOf(db, me, key)
  },

  async requestPlace(place) {
    validate(place?.key ? null : 'Elige el pueblo o la ciudad de la lista.')
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    cleanUpEmptyGroups(db)
    const existing = db.groups.find((g) => g.placeKey === place.key)
    if (existing) {
      join(db, existing, me)
    } else {
      const parentKey = placeParentKey(place)
      db.placeRequests = db.placeRequests.filter((r) => !(r.placeKey === place.key && r.userId === me))
      db.placeRequests.push({ placeKey: place.key, placeName: place.name, parentKey, userId: me, createdAt: nowIso() })
      const requests = db.placeRequests.filter((r) => r.placeKey === place.key)
      if (requests.length >= PLACE_GROUPS.threshold) {
        const now = nowIso()
        const parent = db.groups.find((g) => g.placeKey === parentKey)
        const group = {
          id: uid('g'), kind: 'place', privacy: 'closed', name: place.name, description: '', createdBy: null,
          createdAt: now, updatedAt: now, firstJoinedAt: now, placeLevel: 'municipality', placeKey: place.key, parentId: parent?.id ?? null,
        }
        db.groups.push(group)
        for (const r of requests) {
          db.groupMembers.push({ groupId: group.id, userId: r.userId, role: 'member', joinedAt: now, lastSeenAt: now })
          if (r.userId !== me) db.groupNotices.push({ id: uid('gn'), kind: 'activated', groupId: group.id, userId: r.userId, groupName: group.name, createdAt: now })
        }
        db.placeRequests = db.placeRequests.filter((r) => r.placeKey !== place.key)
      }
    }
    await commit()
    return placeStatusOf(db, me, place.key)
  },

  async cancelPlaceRequest(key) {
    const db = await getDb()
    const me = requireUserId(db)
    db.placeRequests = db.placeRequests.filter((r) => !(r.placeKey === key && r.userId === me))
    await commit()
  },

  async myPlaceRequests() {
    const db = await getDb()
    const me = requireUserId(db)
    cleanUpEmptyGroups(db)
    return db.placeRequests
      .filter((r) => r.userId === me)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map((r) => ({
        key: r.placeKey,
        name: r.placeName,
        count: db.placeRequests.filter((x) => x.placeKey === r.placeKey).length,
        threshold: PLACE_GROUPS.threshold,
        expiresAt: new Date(Date.parse(r.createdAt) + PLACE_GROUPS.requestDays * DAY_MS).toISOString(),
      }))
  },

  // ---- The Gallinero --------------------------------------------------------------------------

  async listPosts(groupId, { before = null } = {}) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    memberGroup(db, me, groupId)
    const items = db.groupPosts
      .filter((p) => p.groupId === groupId && (!before || p.createdAt < before) && visiblePost(db, me)(p))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    return { items: items.slice(0, GROUPS.pageSize).map((p) => postView(db, me, p)), hasMore: items.length > GROUPS.pageSize }
  },

  async createPost(groupId, { text, photo = null }) {
    validate(rules.max(text, LIMITS.groupPost, 'La publicación'), text.trim() || photo ? null : 'Escribe algo o añade una foto.')
    await latency(150, 350)
    const db = await getDb()
    const me = requireUserId(db)
    memberGroup(db, me, groupId)
    const post = {
      id: uid('gp'),
      groupId,
      authorId: me,
      text: text.trim(),
      photoUrl: photo?.dataUrl ?? null,
      photoWidth: photo?.width ?? null,
      photoHeight: photo?.height ?? null,
      createdAt: nowIso(),
    }
    db.groupPosts.push(post)
    const member = db.groupMembers.find((m) => m.groupId === groupId && m.userId === me)
    member.lastSeenAt = post.createdAt
    await commit()
    return postView(db, me, post)
  },

  async deletePost(postId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const post = db.groupPosts.find((p) => p.id === postId)
    ensure(post && isGroupMember(db, post.groupId, me), 'not_found', 'Esta publicación ya no existe.')
    ensure(post.authorId === me || isGroupAdmin(db, post.groupId, me), 'forbidden', 'Solo quien la escribió o quien administra el grupo puede eliminarla.')
    db.groupPosts = db.groupPosts.filter((p) => p.id !== postId)
    db.groupReplies = db.groupReplies.filter((r) => r.postId !== postId)
    db.groupPostGrrs = db.groupPostGrrs.filter((g) => g.postId !== postId)
    await commit()
  },

  async reply(postId, text) {
    validate(rules.required(text, 'La respuesta'), rules.max(text, LIMITS.groupReply, 'La respuesta'))
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const post = visibleGroupPost(db, me, postId)
    db.groupReplies.push({ id: uid('gr'), postId, authorId: me, text: text.trim(), createdAt: nowIso() })
    await commit()
    return postView(db, me, post)
  },

  async deleteReply(replyId) {
    await latency()
    const db = await getDb()
    const me = requireUserId(db)
    const reply = db.groupReplies.find((r) => r.id === replyId)
    const post = reply && db.groupPosts.find((p) => p.id === reply.postId)
    ensure(post && isGroupMember(db, post.groupId, me), 'not_found', 'Esta respuesta ya no existe.')
    ensure(reply.authorId === me || isGroupAdmin(db, post.groupId, me), 'forbidden', 'Solo quien la escribió o quien administra el grupo puede eliminarla.')
    db.groupReplies = db.groupReplies.filter((r) => r.id !== replyId)
    await commit()
    return postView(db, me, post)
  },

  async setGrr(postId, value) {
    await latency(60, 140)
    const db = await getDb()
    const me = requireUserId(db)
    const post = visibleGroupPost(db, me, postId)
    const has = db.groupPostGrrs.some((g) => g.postId === postId && g.userId === me)
    if (value && !has) db.groupPostGrrs.push({ postId, userId: me, createdAt: nowIso() })
    if (!value) db.groupPostGrrs = db.groupPostGrrs.filter((g) => !(g.postId === postId && g.userId === me))
    await commit()
    return postView(db, me, post)
  },
}
