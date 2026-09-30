/** What UserAvatar shows for a group: its initials. */
export const groupAvatar = (group) => ({ id: group.id, firstName: group.name, lastName: '', avatarUrl: null })

export const PRIVACY_LABEL = { closed: 'Grupo cerrado', secret: 'Grupo secreto' }

const PLACE_LABEL = { community: 'Comunidad', province: 'Provincia', municipality: 'Municipio' }

/** "Grupo cerrado", "Grupo secreto" or, for places, "Provincia", "Municipio"... */
export const groupKindLabel = (group) => (group.kind === 'place' ? PLACE_LABEL[group.placeLevel] : PRIVACY_LABEL[group.privacy])

export const ROLE_LABEL = { owner: 'Propietario', admin: 'Administra', member: 'Miembro' }

export const isGroupAdminRole = (role) => role === 'owner' || role === 'admin'

/** What members who are not your friends see of you in a group. */
export const GROUP_SHARE_OPTIONS = [
  { value: 'basic', label: 'Solo mi nombre y mi foto' },
  { value: 'info', label: 'También mi información (ciudad, estudios, trabajo, cumpleaños)' },
  { value: 'full', label: 'Mi perfil completo' },
]

/** Notices of a group. */
export const GROUP_NOTIFY_OPTIONS = [
  { value: 'all', label: 'Todas las publicaciones nuevas' },
  { value: 'mentions', label: 'Solo cuando me mencionan' },
  { value: 'none', label: 'Nada' },
]
