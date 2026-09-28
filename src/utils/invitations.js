/** The personal link a friend opens to create their account. */
export const invitationLink = (token) => `${window.location.origin}/register?invite=${encodeURIComponent(token)}`
