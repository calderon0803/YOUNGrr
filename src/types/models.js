// Domain model of YOUNGrr, documented with JSDoc typedefs.
// It mirrors the tables in supabase/migrations. Import with:
//   /** @typedef {import('@/types/models').PostView} PostView */

/**
 * @typedef {'post' | 'photo'} TargetType
 * @typedef {'idle' | 'loading' | 'success' | 'error'} LoadStatus
 * @typedef {'everyone' | 'friends' | 'only_me'} Visibility
 * @typedef {'everyone' | 'friends_of_friends' | 'nobody'} RequestPolicy
 * @typedef {'system' | 'light' | 'dark'} ThemePreference
 * @typedef {'self' | 'none' | 'request_sent' | 'request_received' | 'friends'} FriendshipStatus
 * @typedef {'going' | 'maybe' | 'declined' | 'pending'} RsvpStatus
 * @typedef {'grr_post' | 'grr_photo' | 'comment_post' | 'comment_photo' | 'friend_request'
 *   | 'friend_accepted' | 'event_invite' | 'message' | 'photo_tag'} NotificationType
 */

/**
 * @typedef {object} UserAccount
 * @property {string} id
 * @property {string} email
 * @property {string | null} passwordHash  SHA-256(salt + password); null for demo accounts
 * @property {string | null} salt
 * @property {string} createdAt
 */

/**
 * @typedef {object} Profile
 * @property {string} id
 * @property {string} firstName
 * @property {string} lastName
 * @property {string | null} avatarUrl   public bucket (basic identification)
 * @property {string | null} coverPath   private bucket; coverUrl is a signed URL when visible
 * @property {string} city               optional (only for "Cerca de ti")
 * @property {number | null} cityLat     town-level coordinates; only ever sent to their owner
 * @property {number | null} cityLng
 * @property {string} bio
 * @property {string | null} birthday    YYYY-MM-DD, only for its owner
 * @property {string | null} birthdayDay MM-DD, what other people get
 * @property {string} studies
 * @property {string} work
 * @property {boolean} needsSetup        account created by hand, profile pending
 * @property {boolean} mustChangePassword temporary password not changed yet
 * @property {boolean} adultConfirmed    confirmed 18+ (the birth date is not stored)
 * @property {string | null} termsVersion version of the terms and privacy policy accepted
 * @property {string} createdAt
 */

/**
 * @typedef {object} ProfileSummary
 * @property {string} id
 * @property {string} firstName
 * @property {string} lastName
 * @property {string | null} avatarUrl
 */

/**
 * @typedef {object} UserSettings
 * @property {{ profileVisibility: Visibility, cityVisibility: Visibility,
 *   distanceVisibility: Visibility, friendRequests: RequestPolicy }} privacy
 *   profileVisibility also governs posts and photos (account and profile share one setting).
 * @property {{ grr: boolean, comments: boolean, friendRequests: boolean, events: boolean, messages: boolean, tags: boolean }} notifications
 * @property {{ theme: ThemePreference }} appearance
 * @property {{ radiusKm: 10 | 25 | 50 }} nearby   radius of the "Cerca de ti" feed
 */

/**
 * @typedef {ProfileSummary & { city: string, friendship: FriendshipStatus, mutualFriends: number, canSendRequest: boolean }} PersonView
 */

/**
 * @typedef {object} ProfileView
 * @property {Profile} profile
 * @property {FriendshipStatus} friendship
 * @property {number} friendsCount
 * @property {number} mutualFriends
 * @property {number} postsCount
 * @property {number} photosCount
 * @property {boolean} canViewProfile
 * @property {boolean} canSendRequest
 */

/**
 * @typedef {object} Friendship   Stored once per pair, userA < userB.
 * @property {string} userA
 * @property {string} userB
 * @property {string} createdAt
 *
 * @typedef {object} FriendRequest
 * @property {string} id
 * @property {string} fromId
 * @property {string} toId
 * @property {'pending' | 'accepted' | 'rejected' | 'cancelled'} status
 * @property {string} createdAt
 * @property {string | null} respondedAt
 */

/**
 * A status (one short phrase per person) or a "ha subido N fotos al álbum"
 * item. There are no free posts.
 * @typedef {object} Post
 * @property {string} id
 * @property {string} authorId
 * @property {'status' | 'album_upload'} kind
 * @property {string} text  The status; empty for album uploads.
 * @property {string | null} albumId
 * @property {string[]} photoIds
 * @property {string | null} photoId
 * @property {string} createdAt
 * @property {string | null} updatedAt
 *
 * @typedef {object} Comment
 * @property {string} id
 * @property {TargetType} targetType
 * @property {string} targetId
 * @property {string} authorId
 * @property {string} text
 * @property {string} createdAt
 *
 * @typedef {Comment & { author: ProfileSummary }} CommentView
 *
 * @typedef {object} Grr   Unique on (userId, targetType, targetId).
 * @property {string} id
 * @property {string} userId
 * @property {TargetType} targetType
 * @property {string} targetId
 * @property {string} createdAt
 */

/**
 * @typedef {Post & {
 *   author: ProfileSummary,
 *   photo: { id: string, url: string, width: number, height: number, albumId: string } | null,
 *   grrCount: number,
 *   hasGrr: boolean,
 *   grrBy: ProfileSummary[],
 *   commentCount: number,
 *   comments: CommentView[],
 *   album: { id: string, title: string } | null,
 *   photos: { id: string, url: string, width: number, height: number }[],
 *   photoTotal: number,
 * }} PostView
 *
 * One person in the friends' news (see activity_block_json).
 * @typedef {{
 *   person: ProfileSummary,
 *   lastActivityAt: string,
 *   status: PostView | null,
 *   uploads: PostView[],
 *   newFriends: { person: ProfileSummary, createdAt: string }[],
 *   newFriendsTotal: number,
 *   tagged: { id: string, url: string, width: number, height: number }[],
 *   taggedTotal: number,
 *   nearby?: { city: string | null, distanceKm: number | null },
 * }} ActivityBlock
 */

/**
 * @typedef {object} Album
 * @property {string} id
 * @property {string} ownerId
 * @property {'user' | 'wall'} kind   "wall" collects photos published from posts
 * @property {string} title
 * @property {string} description
 * @property {string | null} coverPhotoId
 * @property {string} createdAt
 * @property {string} updatedAt
 *
 * @typedef {Album & { owner: ProfileSummary, coverUrl: string | null, photoCount: number }} AlbumView
 *
 * @typedef {object} Photo
 * @property {string} id
 * @property {string} ownerId
 * @property {string} albumId
 * @property {string} url
 * @property {number} width
 * @property {number} height
 * @property {string} caption
 * @property {string} createdAt
 *
 * @typedef {object} PhotoTag
 * @property {string} id
 * @property {string} photoId
 * @property {string} userId
 * @property {string} taggedBy
 * @property {number} x   center of the tagged area, 0-1 relative to the image
 * @property {number} y
 * @property {string} createdAt
 *
 * @typedef {Photo & {
 *   owner: ProfileSummary,
 *   albumTitle: string,
 *   grrCount: number,
 *   hasGrr: boolean,
 *   commentCount: number,
 *   tags: (PhotoTag & { person: ProfileSummary })[],
 *   comments?: CommentView[],
 * }} PhotoView
 */

/**
 * @typedef {object} SocialEvent
 * @property {string} id
 * @property {string} creatorId
 * @property {string} title
 * @property {string} description
 * @property {string | null} imageUrl
 * @property {string} date   YYYY-MM-DD
 * @property {string} time   HH:mm
 * @property {string} location
 * @property {string} createdAt
 * @property {string} updatedAt
 *
 * @typedef {object} EventMember
 * @property {string} eventId
 * @property {string} userId
 * @property {RsvpStatus} status
 * @property {string} invitedBy
 * @property {string | null} respondedAt
 *
 * @typedef {SocialEvent & {
 *   creator: ProfileSummary,
 *   myStatus: RsvpStatus | null,
 *   isCreator: boolean,
 *   counts: Record<RsvpStatus, number>,
 *   members: { person: ProfileSummary, status: RsvpStatus }[],
 * }} EventView
 */

/**
 * @typedef {object} Conversation
 * @property {string} id
 * @property {string[]} memberIds
 * @property {string} createdAt
 * @property {string} updatedAt
 *
 * @typedef {object} Message
 * @property {string} id
 * @property {string} conversationId
 * @property {string} senderId
 * @property {string} text
 * @property {string} createdAt
 *
 * @typedef {{ id: string, other: ProfileSummary, lastMessage: Message | null, unreadCount: number, updatedAt: string }} ConversationView
 */

/**
 * @typedef {object} AppNotification
 * @property {string} id
 * @property {string} userId    recipient
 * @property {string} actorId
 * @property {NotificationType} type
 * @property {string} targetId  post, photo, event, conversation or user id
 * @property {string} createdAt
 * @property {string | null} readAt
 *
 * @typedef {AppNotification & { actor: ProfileSummary, detail: string | null, link: string }} NotificationView
 */

export {}
