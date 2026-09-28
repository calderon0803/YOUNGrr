import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const app = (path, name, loader, meta = {}) => ({ path, name, component: loader, meta: { auth: true, ...meta } })

const routes = [
  { path: '/', name: 'landing', component: () => import('@/pages/LandingPage.vue'), meta: { guest: true, layout: 'auth' } },
  { path: '/login', name: 'login', component: () => import('@/pages/LoginPage.vue'), meta: { guest: true, layout: 'auth', title: 'Entrar' } },
  { path: '/register', name: 'register', component: () => import('@/pages/RegisterPage.vue'), meta: { guest: true, layout: 'auth', title: 'Crear cuenta' } },

  app('/home', 'home', () => import('@/pages/HomePage.vue'), { title: 'Inicio' }),
  app('/profile', 'my-profile', () => import('@/pages/ProfilePage.vue'), { title: 'Perfil' }),
  app('/profile/:id', 'profile', () => import('@/pages/ProfilePage.vue'), { title: 'Perfil' }),
  app('/post/:id', 'post', () => import('@/pages/PostPage.vue'), { title: 'Publicación' }),
  app('/friends', 'friends', () => import('@/pages/FriendsPage.vue'), { title: 'Amigos' }),
  app('/photos', 'photos', () => import('@/pages/PhotosPage.vue'), { title: 'Fotos' }),
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

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.restore()
  if (to.meta.auth && !auth.isAuthenticated) return { name: 'login', query: to.fullPath !== '/home' ? { next: to.fullPath } : {} }
  if (to.meta.guest && auth.isAuthenticated) return { name: 'home' }
  if (to.name === 'my-profile') return { name: 'profile', params: { id: auth.meId } }
  return true
})

router.afterEach((to) => {
  document.title = to.meta.title ? `${to.meta.title} · YOUNGrr` : 'YOUNGrr'
})
