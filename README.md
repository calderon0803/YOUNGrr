# YOUNGrr

Una red social para ver qué están haciendo tus amigos. **Amigos, no seguidores.**
Tu estado, fotos, álbumes, eventos y mensajes con la gente que conoces, sin
algoritmos, tendencias ni contenido de desconocidos.

La interacción propia de YOUNGrr es **Grr**: el equivalente a "me gusta", con más actitud.
Es binaria (haces Grr o lo quitas), única por persona y contenido, y funciona en
estados y fotografías. Los avisos de «ha subido N fotos» son solo informativos.

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
├── services/        auth, users, friends, posts, interactions, photos, events,
│   │                messages, notifications, search, wall (selectores)
│   ├── local/       backend local (IndexedDB)
│   └── supabase/    backend Supabase
├── stores/          auth, user, feed, friends, photos, events, messages,
│                    notifications, search, ui
├── styles/          tokens (abstracts), tema claro/oscuro, base, partials
├── types/           modelo de datos documentado con JSDoc
└── utils/
```

### Solo por invitación

Como Tuenti, no hay registro abierto. En Inicio, **Invitar a tus amigos** muestra tus
invitaciones disponibles: 1 al registrarte y 1 más cada semana, hasta 5 en total. Escribes el correo de tu amigo y la app te da
un enlace personal (`/register?invite=…`) para mandárselo por donde quieras. La cuenta
solo se puede crear con ese correo, el enlace caduca a los 30 días y al registrarse os
hacéis amigos automáticamente. Las invitaciones pendientes se pueden cancelar y se
recuperan.

La base de datos lo impone: un trigger rechaza cualquier alta en `auth.users` sin una
invitación válida para ese correo, aunque se llame a la API directamente. Las altas
hechas desde el panel de Supabase (*Invite user*) no pasan por esa comprobación.

### Novedades y visitas

Como en Tuenti, no hay lista de notificaciones ni campana. En Inicio hay un bloque de
**Novedades** con contadores agrupados ("2 mensajes privados nuevos", "1 petición de
amistad", "3 Grr nuevos en tus fotos"...). Cada línea lleva a donde se atiende y
desaparece al visitarlo o responderlo. El total aparece como contador en *Inicio*.
Si hay una sola, lleva directamente a ella. Si hay varias sobre fotos (comentarios, Grr,
etiquetas, invitaciones para compartir), abre una lista con exactamente esas fotos y quién
ha hecho qué; al abrir cada foto se marca como vista solo esa.

Debajo de las Novedades está tu **contador de visitas**, que solo ves tú. YOUNGrr solo
guarda el número: no sabe ni conserva quién visitó, cuándo ni cuántas veces. Cada visitante
cuenta una vez por perfil mientras tiene la app abierta (se recuerda solo en memoria).

### Inicio y perfil al estilo Tuenti

- Navegación con pestañas en la barra superior (en móvil, barra inferior).
- **Inicio** en tres columnas: tu estado ("¿Qué estás haciendo?"), las Novedades y las
  visitas; en el centro las novedades de tus amigos en formato compacto (miniaturas y
  "Grr · Comentar" como enlaces); a la derecha, próximos planes, cumpleaños y sugerencias.
- **Novedades de tus amigos** no es un muro de publicaciones: es la actividad de tus
  amigos, un bloque por persona (como en Tuenti) con su estado y lo que han hecho en los
  últimos 30 días: fotos subidas a un álbum, nuevas amistades y fotos en las que les han
  etiquetado. Los bloques se ordenan por la actividad más reciente.
- **Estado**: una frase breve (140 caracteres) y solo uno a la vez. Se cambia en la línea
  de la portada; el nuevo sustituye al anterior (con sus comentarios y Grr) y dejarla vacía
  lo borra. Admite comentarios y Grr, y se muestra bajo tu nombre en el perfil.
- No hay publicaciones libres: las fotos se suben siempre a un álbum.
- **Perfil** sin portada: foto grande, datos y amigos a la izquierda; nombre, estado y
  pestañas (Tablón, Fotos, Etiquetas, Álbumes, Amigos) a la derecha.
- **Chat** abajo a la derecha (tablet y escritorio): un panel plegable con tus
  conversaciones; cada chat que abres se coloca a su izquierda y se puede minimizar o
  cerrar. Los chats abiertos se recuerdan en el navegador. En móvil, Mensajes sigue
  siendo una página de la barra inferior.
- Tu perfil se abre desde tu nombre en la portada o desde tu foto en la barra superior.
- **Tablón**: lo que te escriben tus amigos en tu perfil. Lo lee quien puede ver tu
  perfil, escriben tú y tus amigos, y lo borra quien lo escribió o tú.

### Cerca de ti

El inicio tiene dos pestañas: **Amigos** y **Cerca de ti**. La segunda muestra
el estado y las fotos subidas de gente a menos de 10, 25 o 50 km (lo elige cada usuario) de su ciudad
o pueblo. Es **opcional**: sin pueblo se puede usar todo lo demás. Se elige con un
buscador de OpenStreetMap (Nominatim), que recibe el texto escrito (a partir de 3 letras,
como mucho una búsqueda por segundo), la IP y el origen de la web; nunca la cuenta.

- Quién aparece lo decide **Quién puede ver mi perfil** (cualquier persona o solo mis
  amigos): cuenta y perfil comparten la privacidad, y el estado y las fotos la
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
3. Cada `src/services/*.service.js` elige la implementación local
   (`services/local/*.local.js`) o la de Supabase (`services/supabase/*.supabase.js`),
   con las mismas firmas; stores y componentes no cambian.

Estado de la conexión con Supabase (`src/services/supabase/`):

- **Hecho:** registro, login, sesión, cierre de sesión y cambio de contraseña con Supabase
  Auth. El registro guarda nombre y pueblo (con coordenadas) en los metadatos y el trigger
  crea el perfil, los ajustes y el álbum del muro.
- **Hecho:** perfiles (ver, editar, avatar y portada en el bucket público `avatars`,
  visitas), ajustes y amigos (lista, solicitudes, buscar personas, sugerencias). La
  privacidad se calcula en funciones de la base de datos como el usuario que consulta.
- **Hecho:** estado, novedades de amigos por bloques y «Cerca de ti», comentarios y Grr.
  Las fotos van al bucket privado `photos` y se muestran con URLs firmadas.
- **Hecho:** fotos y álbumes (subir, pies de foto, portada, visor, etiquetas, fotos
  compartidas con invitación y novedades «ha subido N fotos al álbum»), eventos (con
  imagen privada que solo ven los invitados), mensajes privados, búsqueda global y
  contadores de Novedades. Los grupos de Novedades se construyen igual en los dos
  backends (`services/notifications.groups.js`).
- **Permisos de las funciones:** solo las RPC de la app y las funciones que usan las
  políticas RLS se pueden ejecutar desde la API, y solo con sesión iniciada. Las
  funciones internas (las que reciben el usuario como parámetro) no son accesibles, y
  ninguna función nueva lo es por defecto: cada migración concede las suyas.

En el panel de Supabase, *Authentication > URL Configuration*: pon como *Site URL* la
dirección de la app y añade a las *Redirect URLs*, para cada dirección donde se sirva
(local, Netlify y el dominio propio cuando exista): `/login` (confirmación de correo),
`/reset-password` (recuperar contraseña) y `/settings/account` (cambio de correo).

Nunca pongas la clave `service_role` en el frontend: la anon key es pública y RLS
protege los datos.

## Seguridad y privacidad

- **Escrituras solo por RPC.** Las tablas solo tienen políticas de lectura; todo cambio
  pasa por funciones de la base de datos que validan las reglas. Una ruta de Storage solo
  la puede registrar el dueño de su carpeta, y un archivo privado solo se lee a través de
  una fila que el lector puede ver.
- **Storage.** `photos` y `covers` son privados (URLs firmadas de 1 h); `avatars` es público
  (foto de perfil, identificación básica). Los tres solo aceptan JPEG con tamaño limitado.
- **Solo mayores de 18 años.** El registro pide la fecha de nacimiento; la base de datos
  rechaza el alta si no llega a 18 años y **no guarda la fecha**, solo la confirmación. Es
  una declaración del usuario: no hay verificación de identidad.
- **Perfil privado.** Cualquiera con sesión encuentra el nombre y la foto; el resto
  (estado, fotos, álbumes, tablón, amigos, información) solo lo ven sus amigos. Los demás
  ven el cumpleaños sin el año; las coordenadas solo las ve su dueño.
- **Mensajes.** Solo los participantes leen una conversación. Cada uno puede eliminar sus
  mensajes: el texto se borra para los dos y queda «Mensaje eliminado».
- **Bloqueos.** Desde un perfil se puede bloquear a alguien: se rompe la amistad y las
  solicitudes pendientes, y en los dos sentidos dejáis de ver el contenido, de escribiros
  y de aparecer en búsquedas y sugerencias. La otra persona no recibe ningún aviso. La
  lista está en *Configuración > Privacidad*.
- **Reportes y moderación.** Se pueden reportar estados, fotos, comentarios, mensajes
  del tablón, perfiles y mensajes privados. Los moderadores (tabla `moderators`) los
  revisan en `/moderation`. Si retiran una foto, también se borra su archivo.
- **Límites de uso.** Cada persona tiene un máximo por minuto de mensajes, comentarios,
  solicitudes, reportes, subidas y búsquedas. Si lo supera, ve «Vas demasiado rápido».
- **Configuración inicial obligatoria.** Mientras falte cambiar la contraseña
  provisional, confirmar la edad o completar el perfil, la API solo permite esas acciones.
- **Subidas.** Solo con nombre aleatorio `.jpg` dentro de la carpeta propia. Al entrar,
  se borran las fotos de perfil y portadas antiguas que ya no se usan.
- **Cuenta.** En *Configuración > Cuenta*: cambiar el correo (con confirmación por email),
  descargar mis datos (JSON) y eliminar mi cuenta (borra los archivos de Storage y después
  la cuenta y todos sus datos). Hay recuperación de contraseña por email, con la misma
  respuesta exista o no la cuenta.
- **Cabeceras.** `netlify.toml` define CSP, `frame-ancestors`/`X-Frame-Options`,
  `nosniff`, `Referrer-Policy`, `Permissions-Policy` y HSTS (el porqué de cada directiva
  está comentado allí). La CSP solo permite el host del proyecto de Supabase: si cambia el
  proyecto, hay que cambiarlo también allí.
- **Modo demo.** Una build de producción nunca pasa a modo demo: sin `VITE_DATA_SOURCE`, o
  con `supabase` sin URL o clave, la build falla; en Netlify solo se admite `supabase`.

### Tareas de administración (SQL Editor de Supabase)

Estas funciones no están disponibles desde la app ni la API:

```sql
-- Dar permisos de moderación (la página es /moderation)
insert into moderators (user_id) select id from auth.users where email = 'correo@ejemplo.com';

-- Crear una cuenta a mano: devuelve una contraseña provisional aleatoria (dásela en privado).
-- La persona tendrá que cambiarla, confirmar su edad y completar su perfil al entrar.
select * from admin_create_account('correo@ejemplo.com', 'Nombre');

-- Limpieza de datos sin finalidad (se programa sola con pg_cron si está activado)
select run_retention();

-- Archivos de Storage que ya no usa nadie (bórralos desde el panel de Storage)
select * from admin_storage_orphans();
```

Los plazos de `run_retention()` están en la tabla `retention_settings` y coinciden con los de
la política de privacidad: si cambias uno, cambia también el otro.

## Textos legales

- **Condiciones de uso** (`/legal/terms`) y **política de privacidad** (`/legal/privacy`), en
  `src/pages/TermsPage.vue` y `src/pages/PrivacyPage.vue`. Se leen sin sesión y durante la
  configuración inicial.
- El responsable y el correo de contacto están en `LEGAL` (`src/config/app.js`).
- Al registrarse hay que aceptarlos, y la base de datos guarda la versión aceptada. Si los
  cambias, sube la versión en **dos sitios**, `LEGAL.version` y `yg_terms_version()` (con una
  migración nueva). Todo el mundo tendrá que aceptarlos de nuevo al entrar; quien no quiera
  puede descargar sus datos y eliminar su cuenta desde esa misma pantalla.
- «Descargar mis datos» incluye las conversaciones completas (mensajes enviados y recibidos).

## Diseño

- Paleta: azul tinta de marca, grises azulados y un único acento coral para Grr.
  Todos los colores son tokens (`src/styles/abstracts/_colors.scss`) que apuntan a
  variables CSS del tema claro y oscuro (`src/styles/base/_theme.scss`).
- Logotipo tipográfico `YOUNG` + `rr`, con una versión reducida `Grr` para el icono de la app.
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
