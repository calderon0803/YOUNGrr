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
invitaciones disponibles: 1 al registrarte y 1 más cada semana, hasta 5 en total. Con un
botón se crea un enlace personal (`/register?invite=…`) sin rellenar nada, para mandarlo
por donde quieras. Sirve para **una sola cuenta**, con el correo que elija quien se
registra, caduca a los 30 días y al registrarse os hacéis amigos automáticamente. Los
enlaces sin usar se pueden cancelar y se recupera la invitación. Como cualquiera que tenga
el enlace puede usarlo, conviene mandarlo solo a quien quieres invitar.

La base de datos lo impone: un trigger rechaza cualquier alta en `auth.users` sin un
enlace de invitación válido y sin usar, aunque se llame a la API directamente. Las altas
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
cuenta una vez por perfil cada 6 horas, desde cualquier dispositivo. Para saberlo, cada
visita deja en la tabla `visit_marks` solo un SHA-256 de una sal secreta (`app_secrets`),
el visitante y el perfil, que nadie puede leer por la API y que se borra a las 6 horas. El
navegador, además, no reenvía la visita al recargar.

### Grupos

Sección «Grupos» en la cabecera y en la barra inferior del móvil, y un bloque «Tus grupos» en
Inicio con las publicaciones nuevas de cada uno (lo de los grupos no se mezcla con las
Novedades de tus amigos).

- **Cerrados o secretos.** Un grupo cerrado lo encuentra cualquiera por su nombre y pide
  entrar; uno secreto solo lo ven sus personas y los invitados. Lo de dentro (el Gallinero,
  las personas y los eventos) es solo para sus miembros.
- **Papeles.** Quien lo crea es propietario: nombra administradores y puede pasar el grupo.
  Quien administra acepta solicitudes, edita el grupo, quita miembros y borra publicaciones.
  Si sale el propietario, lo sustituye el administrador más antiguo (o el miembro más antiguo);
  un grupo vacío se borra.
- **Límites.** Hasta 200 personas y 10 grupos creados por persona (`GROUPS` en
  `src/config/app.js` y en la migración `groups`). Los miembros invitan a sus amigos.
- **Sin grupos vacíos.** Si en 7 días no se une nadie, la tarea nocturna `yg_cleanup_groups()`
  lo borra y avisa a quien lo creó.
- **Gallinero.** Publicaciones de hasta 280 caracteres con una foto opcional (bucket privado
  `photos`, solo la leen los miembros), respuestas y Grr. Los bloqueos ocultan lo de la otra
  persona. Un reporte llega a moderación con el 30% de los miembros (entre 3 y 10).
- **Eventos de grupo.** Al crear un evento se elige «Con invitación», «Público» o «De un
  grupo»; los de grupo los ven sus miembros, que se apuntan sin invitación.
- **Privacidad por grupo.** La de amigos y la de grupos son distintas: para los amigos solo
  cuentan los ajustes de amigos. En cada grupo, cada persona elige qué ve de ella la gente
  del grupo que no es su amiga: nombre y foto (por defecto), también su información o el perfil
  completo (`group_members.profile_share`, `yg_group_share()`). Todo el mundo aparece con su
  nombre en la lista de personas.
- **Avisos por grupo:** todas las publicaciones nuevas, solo menciones o nada. Los grupos de
  lugares solo avisan de menciones. Los valores por defecto y quién puede invitarte a grupos
  están en *Configuración > Privacidad*.
- **Menciones.** «@» abre una lista con la gente del grupo o del chat; la base de datos solo
  guarda a quien se nombra de verdad en el texto (`yg_clean_mentions()`).
- **Novedades del grupo.** Una pestaña con quién ha entrado, los eventos nuevos y la actividad
  de sus personas (de quien puedes ver), como las Novedades de tus amigos. El Gallinero va aparte.

**Imágenes.** Los grupos de usuarios pueden tener imagen (la ponen propietario y administradores; bucket privado
`photos`, la ve quien ve el grupo). Los de lugares llevan la bandera de su comunidad o provincia (`public/flags`,
miniaturas de Wikimedia Commons con su autoría en `src/config/flags.js` y en Créditos); los pueblos, la de su
provincia, y las provincias sin bandera oficial, la de su comunidad.

**Grupos de lugares.** Hay uno por cada comunidad autónoma y provincia (las comunidades de una
sola provincia, como Cantabria, son un único grupo), con las claves de `src/config/places.js`.
Cualquiera entra directamente, no tienen límite de personas ni cuentan en los 10 grupos y los
administra la moderación (que puede nombrar administradores). Dentro solo se ve por nombre a
los amigos y a quien administra.

Los de pueblos y ciudades no los crea nadie a mano, para no tener grupos vacíos: se piden con
«Quiero un grupo de…», eligiendo el lugar en la lista del buscador (su id de OpenStreetMap es la
clave del grupo, así que no hay duplicados). Solo se ve cuántas personas lo han pedido. Con 5
peticiones (`app_settings.place_group_threshold`, y `PLACE_GROUPS` para la demo) se crea el
grupo, dentro de su provincia, con todos ellos, que reciben un aviso. Las peticiones caducan a
los 90 días.

### Gustos

Pestaña «Gustos» en el perfil: artistas (MusicBrainz), películas y series (TMDB), buscados en sus
catálogos para que el mismo título sea el mismo para todos. Las películas y series se valoran con
estrellas, de media a cinco; los artistas solo se añaden. Los ve quien puede ver el perfil y salen
en las Novedades de los amigos. La clave de TMDB va en `VITE_TMDB_API_KEY` (es pública por diseño:
solo lee el catálogo); sin ella, la demo usa un catálogo de ejemplo (`src/data/catalog.js`). Hay
que citar a TMDB: «Este producto usa la API de TMDB, pero TMDB no lo avala ni lo certifica».

### Experiencia y niveles

Algunas acciones dan experiencia (XP) y la experiencia sube el nivel
(`xp_for_level(n) = round(50 * (n - 1)^1.5)`). Lo calcula todo la base de datos, y está pensado
para que no se pueda farmear:

- Lo publicado (fotos, comentarios en lo de otros, mensajes en tablones ajenos, Gallinero,
  gustos, Grr recibidos, amistades) solo cuenta si sigue ahí **7 días después**: hasta entonces
  sale como «en camino». Lo suma cada noche `yg_mature_xp()` (pg_cron, 3:40).
- Cada cosa cuenta una vez (`xp_ledger`, clave usuario + origen + referencia) y hay límites por
  día de publicación (amistades, por semana). Los estados no dan nada.
- Al momento: entrar cada día (+5 a los 7 días seguidos y +20 a los 30), completar el perfil,
  invitaciones que acaban en alta y logros (no los de nivel).
- La experiencia ganada no se pierde aunque luego se borre algo; solo la quita la moderación
  cuando retira un contenido (el de ese contenido y sus Grr, trigger en `moderation_removals`).

El nivel lo ve quien puede ver el perfil; la experiencia exacta y lo pendiente, solo uno mismo
(caja de Inicio). Los títulos (Habitual, De la casa, Veterano, Institución, Leyenda) son logros
`nivel_*`, que no se comparten ni dan experiencia. No hay clasificación. Las cantidades y
límites están en `yg_xp_candidates()` / `yg_award_instant()` y en `src/config/levels.js`: si
cambias uno, cambia el otro.

### Logros

La base de datos calcula los logros a partir de lo que ya existe (fotos, amigos, planes, Grr,
tablón), así que no se pueden falsear, y un nivel conseguido no se pierde. Los que tienen
niveles son bronce, plata, oro y platino. Se comprueban al abrir Inicio o tus logros y cada
noche (pg_cron). Se ven en la columna izquierda del perfil, para quien puede verlo. Durante
7 días desde que se consigue uno (o un nivel nuevo) se puede compartir, y entonces aparece
en las Novedades de tus amigos. Los que ya cumplía cada cuenta al estrenarse los logros se dan
sin opción de compartir, para no llenar las Novedades de golpe.

Los nombres, iconos y textos están en `src/config/achievements.js`; los códigos y umbrales,
en `yg_achievement_defs()`: si cambias uno, cambia el otro. **Fundador** es para las cuentas
creadas antes de la versión 1.0.0: al publicarla, fija la fecha con una migración:

```sql
update app_settings set value = now()::text where key = 'founders_until';
```

### Inicio y perfil al estilo Tuenti

- Navegación con pestañas en la barra superior (en móvil, barra inferior).
- **Inicio** en tres columnas: tu estado ("¿Qué estás haciendo?"), las Novedades y las
  visitas; en el centro las novedades de tus amigos en formato compacto (miniaturas y
  "Grr · Comentar" como enlaces); a la derecha, próximos planes, cumpleaños y sugerencias.
- **Novedades de tus amigos** no es un muro de publicaciones: es la actividad de tus
  amigos de los últimos 30 días, con **una tarjeta por amigo y día** (hora de España): lo
  nuevo crea una tarjeta arriba y las de otros días se quedan como estaban. Cada tarjeta
  lleva el estado si lo puso ese día y lo que hizo: fotos subidas (3 y «y N subidas más»),
  nuevas amistades, fotos en las que le han etiquetado y logros compartidos. Las tarjetas
  se ordenan por su actividad más reciente.
- **Estado**: una frase breve (140 caracteres) y solo uno a la vez. Se cambia en la línea
  de la portada; el nuevo sustituye al anterior (con sus comentarios y Grr) y dejarla vacía
  lo borra. Admite comentarios y Grr, y se muestra bajo tu nombre en el perfil.
- No hay publicaciones libres. Todas las fotos se suben a **Mis fotos**, el álbum por
  defecto de cada persona, que no se puede borrar. Los demás álbumes son colecciones:
  se les añaden fotos ya subidas (una foto puede estar en varios) y al borrarlos se
  elige si se borra solo el álbum, también las fotos que solo están en él o todas.
- **Perfil** sin portada: foto grande, datos y amigos a la izquierda; nombre, estado y
  pestañas (Tablón, Fotos, Etiquetas, Álbumes, Amigos) a la derecha.
- **Chat** abajo a la derecha (tablet y escritorio): un panel plegable con tus
  conversaciones; cada chat que abres se coloca a su izquierda y se puede minimizar o
  cerrar. Los chats abiertos se recuerdan en el navegador. En móvil, Mensajes sigue
  siendo una página de la barra inferior.
- Tu perfil se abre desde tu nombre en la portada o desde tu foto en la barra superior.
- **Tablón**: lo que te escriben tus amigos en tu perfil. Lo lee quien puede ver tu
  perfil, escriben tú y tus amigos, y lo borra quien lo escribió o tú.

### Ciudad o pueblo

Es **opcional**: sin pueblo se puede usar todo. Se elige con un buscador de OpenStreetMap
(Nominatim), que recibe el texto escrito (a partir de 3 letras, como mucho una búsqueda por
segundo), la IP y el origen de la web; nunca la cuenta. Solo se guarda el nombre (un trigger
descarta las coordenadas), lo ve quien permite **Quién puede ver mi ciudad o pueblo** y sirve
para sugerir los grupos de tu zona. «Cerca de ti» ya no existe: la sustituyen los grupos de
lugares.

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
  Auth. El registro guarda nombre y pueblo en los metadatos y el trigger
  crea el perfil, los ajustes y el álbum Mis fotos.
- **Hecho:** perfiles (ver, editar, avatar y portada en el bucket público `avatars`,
  visitas), ajustes y amigos (lista, solicitudes, buscar personas, sugerencias). La
  privacidad se calcula en funciones de la base de datos como el usuario que consulta.
- **Hecho:** estado, novedades de amigos por bloques, comentarios y Grr.
  Las fotos van al bucket privado `photos` y se muestran con URLs firmadas.
- **Hecho:** fotos y álbumes (subir, pies de foto, portada, visor, etiquetas, fotos
  compartidas con invitación y novedades «ha subido N fotos»), eventos (con
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
  ven el cumpleaños sin el año.
- **Mensajes.** Solo los participantes leen una conversación. Cada uno puede eliminar sus
  mensajes: el texto se borra para todos y queda «Mensaje eliminado».
- **Chats de grupo.** Con amigos (no hace falta que lo sean entre sí), hasta 20 personas. Quien
  lo crea le pone nombre, invita (se entra solo aceptando la invitación) y quita gente; cualquiera puede salir, y si sale el creador lo
  sustituye el miembro más antiguo. No se puede añadir a alguien con quien hay un bloqueo; si el
  bloqueo llega después, los dos siguen pero dejan de ver los mensajes del otro. Al borrar una
  cuenta se van sus mensajes y el chat sigue. Sus mensajes llegan a moderación con 2 reportes si
  el chat tiene más de 5 personas.
- **Invitaciones.** Cada enlace es un código aleatorio de 32 caracteres, sirve para una
  sola cuenta (si dos personas lo usan a la vez, la segunda alta se cancela) y caduca a los
  30 días. No guarda datos de la persona invitada. Quien lo tenga puede usarlo: por eso se
  avisa de compartirlo solo con quien se quiere invitar.
- **Eventos públicos.** Los ven los amigos de quien los crea y los amigos de sus amigos, sin
  bloqueos de por medio. Quien solo ve el evento (sin estar invitado ni apuntado) ve quién va
  o quizá va, nunca a quien no respondió o dijo que no, ni a nadie con quien tenga un bloqueo.
  La imagen y el buscador siguen las mismas reglas.
- **Álbumes.** Solo se añaden a tus álbumes fotos de las que eres dueño (hasta 200 por vez).
  Un álbum muestra a cada persona solo las fotos que puede ver según la privacidad de sus
  dueños. Borrar un álbum solo borra fotos si se elige y solo las tuyas.
- **Sugerencias de amistad.** Solo personas con amigos en común que admiten tu solicitud,
  hasta 100, con límite por minuto para que no sirvan para sacar el mapa de amistades.
- **Bloqueos.** Desde un perfil se puede bloquear a alguien: se rompe la amistad y las
  solicitudes pendientes, y en los dos sentidos dejáis de ver el contenido, de escribiros
  y de aparecer en búsquedas y sugerencias. La otra persona no recibe ningún aviso. La
  lista está en *Configuración > Privacidad*.
- **Reportes y moderación.** Se pueden reportar estados, fotos, comentarios, mensajes
  del tablón, perfiles y mensajes privados. Reportar no oculta nada. Un contenido llega a
  moderación cuando lo reportan 10 personas distintas (`app_settings.report_threshold`; los
  mensajes privados, con 1) y aparece una sola vez, con el número de reportes y sus motivos,
  sin quién los hizo. Los moderadores (tabla `moderators`) lo revisan en `/moderation` y ven
  un contador en el menú de la cuenta. Los reportes que no llegan al mínimo se borran a los
  90 días.
- **Retiradas y apelaciones.** Retirar contenido tras un reporte lo quita de donde estaba y
  guarda una copia completa aparte (`moderation_removals`, sin acceso por la API). Su dueño
  recibe un aviso en Inicio con el motivo (nunca quién reportó) y tiene 14 días para apelar.
  Los moderadores las resuelven en *Moderación > Apelaciones*: si se acepta, el contenido
  vuelve con sus comentarios, Grr y etiquetas; si se rechaza o nadie apela, se borra del todo.
  El archivo de una foto se borra cuando un moderador abre la página de Moderación, porque
  desde SQL no se pueden borrar archivos de Storage.
- **Logros.** Solo los calcula la base de datos; nadie puede leer ni escribir la tabla
  directamente. Los ve quien puede ver el perfil, y solo se anuncian si su dueño los comparte.
- **Límites de uso.** Cada persona tiene un máximo por minuto de mensajes, comentarios,
  solicitudes, reportes, subidas, búsquedas y sugerencias. Si lo supera, ve «Vas demasiado rápido».
- **Configuración inicial obligatoria.** Mientras falte cambiar la contraseña
  provisional, confirmar la edad, completar el perfil o aceptar las condiciones vigentes, la
  API solo permite esas acciones (y descargar los datos o eliminar la cuenta).
- **Comprobación automática de imágenes.** Antes de subir cualquier imagen (fotos, foto
  de perfil, portada, eventos), el navegador la analiza con NSFWJS (modelo abierto y
  gratuito, en `src/utils/imageCheck.js`) y no deja subir las que parecen tener desnudos o
  contenido sexual. Los umbrales están en `IMAGE_CHECK` (`src/config/app.js`). La foto no
  sale del dispositivo para esto. El modelo (unos MB) se descarga solo la primera vez que
  alguien sube una imagen. Es un primer filtro: quien llame a la API directamente se lo
  salta, y para eso siguen los reportes y la moderación. Si el análisis no puede
  ejecutarse (sin conexión al descargar el modelo, navegador sin WebGL), la imagen no se sube.
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

-- Tareas nocturnas que también programa pg_cron: logros de todos y fin de las retiradas
select yg_check_all_achievements();
select yg_purge_removals();
select yg_cleanup_groups();  -- grupos sin nadie a los 7 días y peticiones de pueblos a los 90
select yg_mature_xp();       -- experiencia de lo publicado hace 7 días

-- Archivos de Storage que ya no usa nadie (bórralos desde el panel de Storage)
select * from admin_storage_orphans();
```

Los plazos de `run_retention()` están en la tabla `retention_settings` y coinciden con los de
la política de privacidad: si cambias uno, cambia también el otro.

## Textos legales

- **Condiciones de uso** (`/legal/terms`) y **política de privacidad** (`/legal/privacy`), en
  `src/pages/TermsPage.vue` y `src/pages/PrivacyPage.vue`. Se leen sin sesión y durante la
  configuración inicial, y con sesión están en el menú de la cuenta y en «Más» (móvil).
- **Aviso legal** (`/legal/notice`), **Avisar de contenido ilegal** (`/legal/report`, también para quien no tiene
  cuenta, por correo) y **Créditos** (`/legal/credits`).
- El responsable, el correo de contacto, el NIF y el domicilio están en `LEGAL` (`src/config/app.js`). **NIF y
  domicilio están vacíos: hay que rellenarlos antes de abrir la web al público.**
- **Contenido ilegal (DSA):** en «Reportar», «Es ilegal» (con tipo y explicación) llega a moderación con un solo
  aviso; el resto de motivos necesita el mínimo de reportes. Al retirar algo, moderación elige la norma incumplida
  (`MODERATION_RULES`, numeradas como en las condiciones) y el aviso al dueño la incluye, con cómo recurrir.
- Documentación interna (registro de tratamientos, evaluación de impacto, brechas, encargados y lo pendiente antes
  de publicar) en [`docs/legal`](docs/legal/README.md).
- Al registrarse hay que aceptarlos, y la base de datos guarda la versión aceptada. Si los
  cambias, sube la versión en **dos sitios**, `LEGAL.version` y `yg_terms_version()` (con una
  migración nueva). Todo el mundo tendrá que aceptarlos de nuevo al entrar; quien no quiera
  puede descargar sus datos y eliminar su cuenta desde esa misma pantalla.
- «Descargar mis datos» incluye las conversaciones completas (mensajes enviados y recibidos)
  y los grupos, con lo publicado en su Gallinero y las peticiones de grupos de pueblos.

## Diseño

- Paleta: azul tinta de marca, grises azulados y un único acento coral para Grr.
  Todos los colores son tokens (`src/styles/abstracts/_colors.scss`) que apuntan a
  variables CSS del tema claro y oscuro (`src/styles/base/_theme.scss`).
- Logotipo tipográfico `YOUNG` + `rr`, con una versión reducida `Grr` para el icono de la app.
- Icono de Grr propio: tres zarpazos en SVG, con estados inactivo, hover, activo,
  pulsado y desactivado, y una microinteracción breve al hacer Grr.
- Sin emojis en la interfaz: solo pueden aparecer en el contenido de los usuarios.
- Mobile-first con breakpoints en 768 px (tablet) y 1200 px (escritorio). En móvil:
  navegación inferior de cuatro accesos (Inicio, Amigos, Mensajes y Más; las fotos están en los perfiles); en tablet y escritorio: barra lateral.

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
