import {
  createAppleSplashScreens,
  defineConfig,
  minimal2023Preset,
} from '@vite-pwa/assets-generator/config'

// Generates favicon, PWA icons, maskable icon, apple-touch-icon and iOS splash screens
// from the reduced "Grr" mark.
export default defineConfig({
  headLinkOptions: { preset: '2023' },
  preset: {
    ...minimal2023Preset,
    maskable: { ...minimal2023Preset.maskable, resizeOptions: { background: '#2350a0' } },
    apple: { ...minimal2023Preset.apple, resizeOptions: { background: '#2350a0' } },
    appleSplashScreens: createAppleSplashScreens(
      {
        padding: 0.35,
        resizeOptions: { background: '#2350a0', fit: 'contain' },
        darkResizeOptions: { background: '#10151d', fit: 'contain' },
        linkMediaOptions: { log: true, addMediaScreen: true, basePath: '/', xhtml: false },
        png: { compressionLevel: 9, quality: 70 },
      },
      ['iPhone 6', 'iPhone X', 'iPhone 11', 'iPhone 13', 'iPhone 14 Pro', 'iPhone 15 Pro Max', 'iPad Air 9.7"', 'iPad Pro 11"'],
    ),
  },
  images: ['public/brand-mark.svg'],
})
