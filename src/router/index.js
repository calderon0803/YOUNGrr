import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useMessagesStore } from '@/stores/messages'
import { useModerationStore } from '@/stores/moderation'
import { BREAKPOINTS } from '@/config/app'

const app = (path, name, loader, meta = {}) => ({ path, name, component: loader, meta: { auth: true, ...meta } })

const routes = [
  // No home page for visitors: straight to sign in (signed-in users go on to Inicio).
  { path: '/', redirect: { name: 'login' } },
  { path: '/login', name: 'login', component: () => import('@/pages/LoginPage.vue'), meta: { guest: true, layout: 'auth', title: 'Entrar' } },
  { path: '/forgot-password', name: 'forgot-password', component: () => import('@/pages/ForgotPasswordPage.vue'), meta: { guest: true, layout: 'auth', title: 'Recuperar contraseña' } },
  // Opened from the email link: Supabase signs the person in for the change.
  { path: '/reset-password', name: 'reset-password', component: () => import('@/pages/ResetPasswordPage.vue'), meta: { layout: 'auth', title: 'Nueva contraseña' } },
  // Readable by everyone, also while completing the account (to accept them).
  { path: '/legal/terms', name: 'terms', component: () => import('@/pages/TermsPage.vue'), meta: { public: true, title: 'Condiciones de uso' } },
  { path: '/legal/privacy', name: 'privacy', component: () => import('@/pages/PrivacyPage.vue'), meta: { public: true, title: 'Política de privacidad' } },
  { path: '/register', name: 'register', component: () => import('@/pages/RegisterPage.vue'), meta: { guest: true, layout: 'auth', title: 'Crear cuenta' } },

  app('/setup', 'setup', () => import('@/pages/SetupPage.vue'), { layout: 'auth', title: 'Completa tu perfil' }),
  app('/home', 'home', () => import('@/pages/HomePage.vue'), { title: 'Inicio' }),
  app('/profile', 'my-profile', () => import('@/pages/ProfilePage.vue'), { title: 'Perfil' }),
  app('/profile/:id', 'profile', () => import('@/pages/ProfilePage.vue'), { title: 'Perfil' }),
  app('/post/:id', 'post', () => import('@/pages/PostPage.vue'), { title: 'Novedad' }),
  app('/friends', 'friends', () => import('@/pages/FriendsPage.vue'), { title: 'Amigos' }),
  // Photos live on the profiles; old links go to your own photos.
  { path: '/photos', redirect: { name: 'my-profile', query: { tab: 'photos' } } },
  app('/photos/news', 'photo-news', () => import('@/pages/PhotoNewsPage.vue'), { title: 'Novedades de tus fotos' }),
  app('/photo/:id', 'photo', () => import('@/pages/PhotoPage.vue'), { title: 'Fotografía' }),
  app('/albums/:id', 'album', () => import('@/pages/AlbumPage.vue'), { title: 'Álbum' }),
  app('/events', 'events', () => import('@/pages/EventsPage.vue'), { title: 'Eventos' }),
  app('/events/:id', 'event', () => import('@/pages/EventPage.vue'), { title: 'Evento' }),
  app('/messages', 'messages', () => import('@/pages/MessagesPage.vue'), { title: 'Mensajes' }),
  app('/messages/:id', 'conversation', () => import('@/pages/MessagesPage.vue'), { title: 'Mensajes' }),
  // Notifications live on the home page as grouped counters.
  { path: '/notifications', redirect: { name: 'home' } },
  app('/search', 'search', () => import('@/pages/SearchPage.vue'), { title: 'Buscar' }),
  app('/settings/:section(account|privacy|notifications|appearance)?', 'settings', () => import('@/pages/SettingsPage.vue'), { title: 'Configuración' }),
  app('/moderation', 'moderation', () => import('@/pages/ModerationPage.vue'), { title: 'Moderación', moderator: true }),
  app('/more', 'more', () => import('@/pages/MorePage.vue'), { title: 'Más' }),

  { path: '/:pathMatch(.*)*', name: 'not-found', component: () => import('@/pages/NotFoundPage.vue'), meta: { title: 'Página no encontrada' } },
]

export const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, saved) {
    if (saved) return saved
    // Opening a photo updates ?photo= without jumping to the top.
    if (to.path === from.path) return false
    return { top: 0 }
  },
})

router.beforeEach(async (to, from) => {
  const auth = useAuthStore()
  await auth.restore()
  if (to.meta.auth && !auth.isAuthenticated) return { name: 'login', query: to.fullPath !== '/home' ? { next: to.fullPath } : {} }
  if (to.meta.guest && auth.isAuthenticated) return { name: 'home' }
  // Pending age, password, profile or terms: first things first (the recovery
  // page sets a new password too, and the legal texts must stay readable).
  if (auth.needsSetup && to.name !== 'setup' && to.name !== 'reset-password' && !to.meta.public) return { name: 'setup' }
  if (to.name === 'setup' && !auth.needsSetup) return { name: 'home' }
  if (to.name === 'my-profile') return { name: 'profile', params: { id: auth.meId }, query: to.query }
  if (to.meta.moderator && !(await useModerationStore().checkModerator())) return { name: 'home' }
  // From tablet up, messages live in the chat dock instead of a page.
  if ((to.name === 'messages' || to.name === 'conversation') && window.matchMedia(`(min-width: ${BREAKPOINTS.tablet}px)`).matches) {
    const messages = useMessagesStore()
    if (to.name === 'conversation') messages.openWindow(String(to.params.id))
    else messages.toggleDock(true)
    return from.matched.length ? false : { name: 'home' }
  }
  return true
})

router.afterEach((to, from, failure) => {
  // Cancelled navigations (e.g. a chat opened in the dock) keep the title.
  if (failure) return
  document.title = to.meta.title ? `${to.meta.title} · YOUNGrr` : 'YOUNGrr'
})
