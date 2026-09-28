# YOUNGrr

Una red social para ver qué están haciendo tus amigos. **Amigos, no seguidores.**
Publicaciones, fotos, álbumes, eventos y mensajes con la gente que conoces, sin
algoritmos, tendencias ni contenido de desconocidos.

La interacción propia de YOUNGrr es **Grr**: el equivalente a "me gusta", con más actitud.
Es binaria (haces Grr o lo quitas), única por persona y contenido, y funciona en
publicaciones y fotografías.

## Arrancar

```bash
npm install
npm run dev
```

Build de producción (incluye service worker y manifest):

```bash
npm run build
npm run preview
```

Sin backend configurado, YOUNGrr usa un backend local en IndexedDB con datos de
demostración. En la pantalla de entrada puedes elegir una cuenta demo (Carlos, Ana,
Pablo, Laura, Javi, Sara o Miguel) o crear tu propia cuenta. Desde
**Configuración > Cuenta** se pueden restablecer los datos de demostración.

## Stack

Vue 3 (Composition API, `<script setup>`) · JavaScript · Vite · Pinia · Vue Router ·
SCSS · vite-plugin-pwa · Lucide (única familia de iconos) · Bricolage Grotesque y
Source Sans 3 (servidas en local).

## Arquitectura

```
UI (pages, components)
  ↓
Stores (Pinia)       estado, caché normalizada, feedback (toasts)
  ↓
Services             única capa que habla con el backend
  ↓
Backend              src/services/local (IndexedDB) · supabase/migrations
```

```
src/
├── assets/
├── components/      common, feed, profile, friends, photos, events,
│                    messages, notifications, settings, auth, layout
├── composables/     toasts, confirmación, focus trap, instalación PWA...
├── config/          constantes de la app (límites, claves, tiempos)
├── data/            datos de demostración (separados del código)
├── layouts/         AppLayout (autenticado) y AuthLayout (público)
├── pages/           una página por ruta
├── router/
├── services/        auth, users, friends, posts, interactions, photos,
│   └── local/       events, messages, notifications, search + backend local
├── stores/          auth, user, feed, friends, photos, events, messages,
│                    notifications, search, ui
├── styles/          tokens (abstracts), tema claro/oscuro, base, partials
├── types/           modelo de datos documentado con JSDoc
└── utils/
```

### Novedades y visitas

Como en Tuenti, no hay lista de notificaciones ni campana. En Inicio hay un bloque de
**Novedades** con contadores agrupados ("2 mensajes privados nuevos", "1 petición de
amistad", "3 Grr nuevos en tus fotos"...). Cada línea lleva a donde se atiende y
desaparece al visitarlo o responderlo. El total aparece como contador en *Inicio*.

Cada perfil muestra su **contador de visitas**: cuentan las visitas de otras personas,
una por persona y día. Nunca se muestra quién ha visitado.

### Cerca de ti

El inicio tiene dos pestañas: **Amigos** y **Cerca de ti**. La segunda muestra
publicaciones de gente a menos de 10, 25 o 50 km (lo elige cada usuario) de su ciudad
o pueblo, que se indica al registrarse con un buscador de OpenStreetMap (Nominatim).

- Quién aparece lo decide **Quién puede ver mi perfil** (cualquier persona o solo mis
  amigos): cuenta y perfil comparten la privacidad, y las publicaciones y las fotos la
  siguen. Las fotos no tienen permisos propios.
- **Quién puede ver mi ciudad o pueblo** y **Quién puede ver a qué distancia estoy**
  son permisos separados. Si se ve el pueblo, no se muestra la distancia; la distancia
  solo aparece cuando el autor oculta el pueblo.
- Solo se guardan coordenadas a nivel de pueblo y nunca salen del backend.

El backend local imita al servidor: cada llamada se hace como el usuario de la sesión
y comprueba permisos y privacidad (`services/local/access.js`), igual que harían las
políticas RLS. Así la interfaz nunca decide sola qué puede ver cada persona.

### Conectar Supabase

`supabase/migrations/` contiene el esquema completo como migración inicial: tablas, restricciones de unicidad
(un Grr por `user_id + post_id` y por `user_id + photo_id`), funciones de privacidad,
políticas RLS, triggers de notificaciones (quitar un Grr no notifica), RPCs y un bucket
privado de Storage para las fotos.

1. Conecta el repositorio en Supabase (Integrations > GitHub, working directory `.`).
   Prueba antes la migración fuera de producción (`supabase start` y `supabase db reset`,
   o un proyecto de pruebas) y después activa *Deploy to production*: cada merge en
   `main` aplica las migraciones nuevas. Una migración aplicada no se edita; los
   cambios van en archivos nuevos dentro de `supabase/migrations/`.
2. Copia `.env.example` a `.env` y rellena `VITE_SUPABASE_URL` y
   `VITE_SUPABASE_ANON_KEY`, y pon `VITE_DATA_SOURCE=supabase`.
3. Implementa los servicios de `src/services/*.service.js` contra Supabase manteniendo
   sus firmas; stores y componentes no cambian.

Estado de la conexión con Supabase (`src/services/supabase/`):

- **Hecho:** registro, login, sesión, cierre de sesión y cambio de contraseña con Supabase
  Auth. El registro guarda nombre y pueblo (con coordenadas) en los metadatos y el trigger
  crea el perfil, los ajustes y el álbum del muro.
- **Hecho:** perfiles (ver, editar, avatar y portada en el bucket público `avatars`,
  visitas), ajustes y amigos (lista, solicitudes, buscar personas, sugerencias). La
  privacidad se calcula en funciones de la base de datos como el usuario que consulta.
- **Pendiente:** publicaciones, fotos, eventos, mensajes, búsqueda global y contadores de
  la portada. Con `VITE_DATA_SOURCE=supabase` esas secciones fallarán hasta migrarlas.

En el panel de Supabase, *Authentication > URL Configuration*: pon como *Site URL* la
dirección de la app y añade `http://localhost:5173/login` a las *Redirect URLs* para
los enlaces de confirmación de correo.

Nunca pongas la clave `service_role` en el frontend: la anon key es pública y RLS
protege los datos.

## Diseño

- Paleta: azul tinta de marca, grises azulados y un único acento coral para Grr.
  Todos los colores son tokens (`src/styles/abstracts/_colors.scss`) que apuntan a
  variables CSS del tema claro y oscuro (`src/styles/base/_theme.scss`).
- Logotipo tipográfico `YOUNG` + `rr`, con una versión reducida `Yrr` para el icono de la app.
- Icono de Grr propio: tres zarpazos en SVG, con estados inactivo, hover, activo,
  pulsado y desactivado, y una microinteracción breve al hacer Grr.
- Sin emojis en la interfaz: solo pueden aparecer en el contenido de los usuarios.
- Mobile-first con breakpoints en 768 px (tablet) y 1200 px (escritorio). En móvil:
  navegación inferior de cinco accesos; en tablet y escritorio: barra lateral.

## PWA

- Manifest, iconos (incluido maskable), `apple-touch-icon` y pantallas de arranque para iOS.
- Service worker de Workbox: precache solo del shell de la app (arranque rápido e instalación).
- **Sin modo offline**: sin conexión no se puede entrar ni usar YOUNGrr. Se muestra una
  pantalla de "No hay conexión a internet" con opción de reintentar, y la capa de
  servicios rechaza cualquier llamada sin red.
- Aviso de nueva versión y botón de instalación en Chrome, Edge y Android.
- iOS y Safari no ofrecen instalación automática: en **Configuración > Cuenta** se
  explican los pasos de "Añadir a pantalla de inicio".

Los iconos se generan desde `public/brand-mark.svg`:

```bash
npm run generate-pwa-assets
```
