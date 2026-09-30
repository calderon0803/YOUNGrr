// Account deletion and data export for the local demo backend (same result as
// delete_my_account() and export_my_data() in the database).

const fullNameOf = (db, id) => {
  const p = db.profiles.find((x) => x.id === id)
  return p ? `${p.firstName} ${p.lastName}` : null
}

/** Removes a person and everything that belongs to or points at them. */
export const purgeLocalUser = (db, id) => {
  const photoIds = new Set(db.photos.filter((p) => p.ownerId === id).map((p) => p.id))
  const postIds = new Set(db.posts.filter((p) => p.authorId === id).map((p) => p.id))
  const eventIds = new Set(db.events.filter((e) => e.creatorId === id).map((e) => e.id))
  const conversationIds = new Set(db.conversations.filter((c) => c.memberIds.includes(id)).map((c) => c.id))
  const gone = (targetType, targetId) => (targetType === 'post' ? postIds.has(targetId) : photoIds.has(targetId))

  db.users = db.users.filter((u) => u.id !== id)
  db.profiles = db.profiles.filter((p) => p.id !== id)
  db.achievements = (db.achievements ?? []).filter((a) => a.userId !== id)
  db.moderationRemovals = (db.moderationRemovals ?? []).filter((r) => r.ownerId !== id)
  delete db.settings[id]
  db.friendships = db.friendships.filter((f) => f.userA !== id && f.userB !== id)
  db.friendRequests = db.friendRequests.filter((r) => r.fromId !== id && r.toId !== id)
  db.albums = db.albums.filter((a) => a.ownerId !== id)
  db.photos = db.photos.filter((p) => !photoIds.has(p.id))
  db.photoOwners = db.photoOwners.filter((o) => o.userId !== id && o.invitedBy !== id && !photoIds.has(o.photoId))
  db.photoTags = db.photoTags.filter((t) => t.userId !== id && t.taggedBy !== id && !photoIds.has(t.photoId))
  db.posts = db.posts.filter((p) => !postIds.has(p.id))
  db.comments = db.comments.filter((c) => c.authorId !== id && !gone(c.targetType, c.targetId))
  db.grrs = db.grrs.filter((g) => g.userId !== id && !gone(g.targetType, g.targetId))
  db.events = db.events.filter((e) => !eventIds.has(e.id))
  db.eventMembers = db.eventMembers.filter((m) => m.userId !== id && !eventIds.has(m.eventId))
  db.conversations = db.conversations.filter((c) => !conversationIds.has(c.id))
  db.conversationMembers = db.conversationMembers.filter((m) => !conversationIds.has(m.conversationId))
  db.messages = db.messages.filter((m) => !conversationIds.has(m.conversationId))
  db.notifications = db.notifications.filter((n) => n.userId !== id && n.actorId !== id)
  db.wallMessages = db.wallMessages.filter((w) => w.profileId !== id && w.authorId !== id)
  db.hiddenPosts = db.hiddenPosts.filter((h) => h.userId !== id && !postIds.has(h.postId))
  // Reports about their content go; reports they filed stay without their name.
  db.reports = db.reports.filter((r) => r.targetOwnerId !== id).map((r) => (r.reporterId === id ? { ...r, reporterId: null } : r))
  db.invitations = db.invitations.filter((i) => i.inviterId !== id && i.usedBy !== id)
}

/** Everything the demo backend holds about a person (others by name, plus their messages to them). */
export const buildLocalExport = (db, id) => {
  const user = db.users.find((u) => u.id === id)
  const profile = db.profiles.find((p) => p.id === id)
  return {
    generated_at: new Date().toISOString(),
    account: { email: user?.email ?? null, created_at: user?.createdAt ?? null },
    profile,
    settings: db.settings[id] ?? null,
    status: db.posts.find((p) => p.authorId === id && (p.kind ?? 'status') === 'status') ?? null,
    albums: db.albums.filter((a) => a.ownerId === id),
    photos: db.photos.filter((p) => p.ownerId === id),
    comments: db.comments.filter((c) => c.authorId === id).map(({ text, targetType, createdAt }) => ({ text, on: targetType, created_at: createdAt })),
    grrs: db.grrs.filter((g) => g.userId === id).map(({ targetType, createdAt }) => ({ on: targetType, created_at: createdAt })),
    friends: db.friendships
      .filter((f) => f.userA === id || f.userB === id)
      .map((f) => ({ name: fullNameOf(db, f.userA === id ? f.userB : f.userA), since: f.createdAt })),
    events_created: db.events.filter((e) => e.creatorId === id),
    // Whole conversations: what the person wrote and what they received.
    conversations: db.conversations
      .filter((c) => c.memberIds.includes(id))
      .map((c) => ({
        with: c.memberIds.filter((x) => x !== id).map((x) => fullNameOf(db, x)),
        messages: db.messages
          .filter((m) => m.conversationId === c.id)
          .map((m) => ({
            from: m.senderId === id ? 'yo' : fullNameOf(db, m.senderId),
            text: m.deletedAt ? null : m.text,
            deleted: !!m.deletedAt,
            created_at: m.createdAt,
          })),
      })),
    wall_messages_written: db.wallMessages.filter((w) => w.authorId === id).map(({ text, createdAt }) => ({ text, created_at: createdAt })),
    invitations_sent: db.invitations.filter((i) => i.inviterId === id).map(({ email, createdAt, usedBy }) => ({ email, created_at: createdAt, used: !!usedBy })),
    achievements: (db.achievements ?? []).filter((a) => a.userId === id).map(({ code, level, earnedAt, sharedAt }) => ({ code, level, earned_at: earnedAt, shared_at: sharedAt })),
    reports_filed: db.reports.filter((r) => r.reporterId === id).map(({ targetType, reason, status, createdAt }) => ({ about: targetType, reason, status, created_at: createdAt })),
  }
}
