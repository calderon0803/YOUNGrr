/** What UserAvatar shows for a group: its initials. */
export const groupAvatar = (group) => ({ id: group.id, firstName: group.name, lastName: '', avatarUrl: null })

export const PRIVACY_LABEL = { closed: 'Grupo cerrado', secret: 'Grupo secreto' }

export const ROLE_LABEL = { owner: 'Propietario', admin: 'Administra', member: 'Miembro' }

export const isGroupAdminRole = (role) => role === 'owner' || role === 'admin'
