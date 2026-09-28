import { createApp } from 'vue'
import { createPinia } from 'pinia'
import '@fontsource-variable/source-sans-3'
import '@fontsource-variable/bricolage-grotesque'
import '@/styles/main.scss'
import App from '@/App.vue'
import { router } from '@/router'
import { applyTheme } from '@/stores/user'
import { STORAGE_KEYS } from '@/config/app'

// Apply the saved theme before the first paint to avoid a flash.
let savedTheme = 'system'
try {
  savedTheme = localStorage.getItem(STORAGE_KEYS.theme) ?? 'system'
} catch {
  // Default theme.
}
applyTheme(savedTheme)

createApp(App).use(createPinia()).use(router).mount('#app')
