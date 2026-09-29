import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

// A published build must use Supabase: without its variables the app would fall
// back to the local demo backend (data only in each browser, demo accounts).
const checkPublishedBuild = (env) => {
  if (process.env.NETLIFY !== 'true') return
  const missing = ['VITE_SUPABASE_URL', 'VITE_SUPABASE_ANON_KEY'].filter((key) => !env[key])
  if (env.VITE_DATA_SOURCE !== 'supabase') missing.unshift('VITE_DATA_SOURCE=supabase')
  if (missing.length) {
    throw new Error(`Faltan variables de entorno en Netlify: ${missing.join(', ')}. Sin ellas la web usaría el modo demo.`)
  }
}

export default defineConfig(({ mode }) => {
  checkPublishedBuild(loadEnv(mode, process.cwd(), 'VITE_'))
  return {
    plugins: [
      vue(),
      VitePWA({
        registerType: 'prompt',
        injectRegister: false,
        includeAssets: ['favicon.ico', 'brand-mark.svg', 'apple-touch-icon-180x180.png'],
        manifest: {
          id: '/',
          name: 'YOUNGrr',
          short_name: 'YOUNGrr',
          description: 'La red social para ver qué están haciendo tus amigos.',
          lang: 'es',
          dir: 'ltr',
          start_url: '/home',
          scope: '/',
          display: 'standalone',
          orientation: 'portrait',
          theme_color: '#2350a0',
          background_color: '#2350a0',
          categories: ['social'],
          icons: [
            { src: 'pwa-64x64.png', sizes: '64x64', type: 'image/png' },
            { src: 'pwa-192x192.png', sizes: '192x192', type: 'image/png' },
            { src: 'pwa-512x512.png', sizes: '512x512', type: 'image/png' },
            { src: 'maskable-icon-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
          ],
          shortcuts: [
            { name: 'Mensajes', url: '/messages', icons: [{ src: 'pwa-192x192.png', sizes: '192x192' }] },
            { name: 'Fotos', url: '/photos', icons: [{ src: 'pwa-192x192.png', sizes: '192x192' }] },
          ],
        },
        workbox: {
          globPatterns: ['**/*.{js,css,html,svg,ico,woff2}', 'pwa-*.png', 'maskable-*.png', 'apple-touch-icon-*.png'],
          globIgnores: ['**/*-cyrillic*', '**/*-greek*', '**/*-vietnamese*'],
          // No offline mode: only the app shell is precached (fast start, install,
          // and the "sin conexión" screen). Data and photos always need the network.
          navigateFallback: '/index.html',
          cleanupOutdatedCaches: true,
        },
        devOptions: { enabled: false },
      }),
    ],
    resolve: {
      alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
    },
    css: {
      preprocessorOptions: {
        scss: { additionalData: '@use "@/styles/abstracts" as *;\n' },
      },
    },
  }
})
