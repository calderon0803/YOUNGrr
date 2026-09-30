import { fullName } from '@/utils/text'

/** A group chat's name, or the other person's name in a direct chat. */
export const conversationName = (conversation) => {
  if (!conversation) return 'Conversación'
  if (conversation.kind === 'group') return conversation.title ?? 'Grupo'
  return conversation.other ? fullName(conversation.other) : 'Conversación'
}

/** What UserAvatar shows: the other person, or the group's initials. */
export const conversationAvatar = (conversation) => {
  if (conversation?.kind === 'group') return { id: conversation.id, firstName: conversation.title ?? 'Grupo', lastName: '', avatarUrl: null }
  return conversation?.other ?? null
}
