import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

// A production build never falls back to the demo backend by accident:
// - no VITE_DATA_SOURCE → error (it must be chosen explicitly);
// - "supabase" without its URL or key → error;
// - "local" (demo) is only allowed outside Netlify, and only when asked for.
const checkBuildConfig = (command, env) => {
  if (command !== 'build') return
  const where = process.env.NETLIFY === 'true' ? 'Netlify' : 'el entorno'
  if (!env.VITE_DATA_SOURCE) {
    throw new Error(`Falta VITE_DATA_SOURCE en ${where}: pon "supabase" (o "local" solo para una build de demostración).`)
  }
  if (env.VITE_DATA_SOURCE === 'supabase') {
    const missing = ['VITE_SUPABASE_URL', 'VITE_SUPABASE_ANON_KEY'].filter((key) => !env[key])
    if (missing.length) throw new Error(`Faltan variables de Supabase en ${where}: ${missing.join(', ')}.`)
  } else if (process.env.NETLIFY === 'true') {
    throw new Error('En Netlify VITE_DATA_SOURCE tiene que ser "supabase": la web no puede publicarse en modo demostración.')
  }
}

export default defineConfig(({ command, mode }) => {
  checkBuildConfig(command, loadEnv(mode, process.cwd(), 'VITE_'))
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
          // The image check model (several MB, see utils/imageCheck.js) is only
          // downloaded when someone uploads an image: it stays out of the precache.
          globIgnores: ['**/*-cyrillic*', '**/*-greek*', '**/*-vietnamese*', '**/group1-shard*', '**/model.min-*'],
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
