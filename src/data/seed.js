// Demo dataset for the local backend. Dates are relative to "now" so the demo
// always reads fresh ("Hace 15 minutos"). Emojis only appear in user content.
import { toDateInput } from '@/utils/time'
import { NEARBY_DEFAULT_RADIUS_KM } from '@/config/app'

const MIN = 60 * 1000
const HOUR = 60 * MIN
const DAY = 24 * HOUR

const ago = ({ d = 0, h = 0, m = 0 } = {}) => {
  return new Date(Date.now() - d * DAY - h * HOUR - m * MIN).toISOString()
}

const inDays = (days) => {
  return toDateInput(new Date(Date.now() + days * DAY))
}

const photoUrl = (seed, w = 1200, h = 800) => `https://picsum.photos/seed/yg-${seed}/${w}/${h}`
const avatar = (kind, n) => `https://randomuser.me/api/portraits/${kind}/${n}.jpg`

const PEOPLE = [
  ['carlos', 'Carlos', 'Calderón', avatar('men', 32), 'Santander', 'Ingeniería y playa, por ese orden (casi siempre).', '2001-03-14', 'Ingeniería Civil · Universidad de Cantabria', 'Becario en un estudio de ingeniería'],
  ['ana', 'Ana', 'Ruiz', avatar('women', 44), 'Santander', 'Si hay plan, me apunto. Fotografía analógica los domingos.', '2001-09-30', 'Periodismo · UCM', 'Redactora en prácticas'],
  ['pablo', 'Pablo', 'Gómez', avatar('men', 46), 'Torrelavega', 'Portero los domingos, cocinero el resto de la semana.', '2000-11-02', 'ADE · Universidad de Cantabria', ''],
  ['laura', 'Laura', 'Fernández', avatar('women', 65), 'Santander', 'Estadística, cámara y conciertos.', '2002-01-21', 'Matemáticas · Universidad de Cantabria', ''],
  ['javi', 'Javi', 'Martín', avatar('men', 75), 'Santander', 'Corriendo por el Sardinero a las 7 de la mañana.', '2001-06-08', 'CAFYD', 'Monitor en el club de atletismo'],
  ['sara', 'Sara', 'López', avatar('women', 68), 'Madrid', 'Recién aterrizada en Madrid. Echo de menos el norte.', '2001-10-11', 'Diseño · ESNE', 'Diseñadora junior'],
  ['miguel', 'Miguel', 'Herrera', avatar('men', 22), 'Bilbao', 'Guitarra, surf y bocadillos de calamares.', '2000-04-19', 'Música · Musikene', ''],
  ['lucia', 'Lucía', 'Ferrer', avatar('women', 12), 'Valencia', 'Bióloga marina en construcción.', '2002-05-05', 'Biología · UV', ''],
  ['diego', 'Diego', 'Navarro', avatar('men', 85), 'Oviedo', '', null, '', 'Cocinero'],
  ['marta', 'Marta', 'Sanz', avatar('women', 90), 'Madrid', 'Perfil privado, pero se aceptan planes.', null, 'Arquitectura · UPM', ''],
  ['alvaro', 'Álvaro', 'Prieto', avatar('men', 11), 'Salamanca', 'No acepto solicitudes, lo siento.', null, '', ''],
  ['irene', 'Irene', 'Castro', avatar('women', 29), 'Gijón', 'Retratos y viajes.', null, 'Bellas Artes', ''],
  // Neighbours of Carlos who are not his friends, for the "Cerca de ti" feed.
  ['nerea', 'Nerea', 'Gutiérrez', avatar('women', 33), 'Santander', 'Vintage, mercadillos y bicis viejas.', null, 'Historia del Arte · UC', ''],
  ['hugo', 'Hugo', 'Revuelta', avatar('men', 52), 'Laredo', 'Surf de invierno y fotos de atardeceres.', null, '', 'Socorrista'],
  ['claudia', 'Claudia', 'Sainz', avatar('women', 57), 'Comillas', 'Canto en un coro y doy clases de piano.', null, 'Conservatorio de Santander', ''],
  ['oscar', 'Óscar', 'Pellón', avatar('men', 64), 'Castro Urdiales', 'Pádel, pádel y más pádel.', null, '', 'Fisioterapeuta'],
  ['bea', 'Bea', 'Arce', avatar('women', 79), 'Santander', 'Cuenta privada.', null, '', ''],
  ['ruben', 'Rubén', 'Ceballos', avatar('men', 36), 'Reinosa', 'Montaña todo el año.', null, '', 'Guía de montaña'],
]

// Town-level coordinates (never exact positions).
const CITY_COORDS = {
  Santander: [43.4623, -3.81],
  Torrelavega: [43.3494, -4.0479],
  Laredo: [43.4098, -3.4196],
  Comillas: [43.3857, -4.2914],
  'Castro Urdiales': [43.3846, -3.2164],
  Reinosa: [43.0012, -4.1373],
  Madrid: [40.4168, -3.7038],
  Bilbao: [43.263, -2.935],
  Valencia: [39.4699, -0.3763],
  Oviedo: [43.3614, -5.8494],
  Salamanca: [40.9701, -5.6635],
  'Gijón': [43.5322, -5.6611],
}

const FRIENDS = [
  ['carlos', 'ana', 900], ['carlos', 'pablo', 1400], ['carlos', 'laura', 700], ['carlos', 'javi', 7], ['carlos', 'sara', 400],
  ['ana', 'laura', 800], ['ana', 'sara', 1000], ['ana', 'pablo', 600], ['ana', 'irene', 3],
  ['pablo', 'javi', 300], ['laura', 'sara', 500], ['laura', 'lucia', 5],
  ['javi', 'miguel', 250], ['sara', 'miguel', 350], ['miguel', 'diego', 90],
  ['pablo', 'hugo', 420], ['sara', 'nerea', 380],
  ['lucia', 'marta', 120], ['diego', 'alvaro', 60], ['marta', 'irene', 40],
]

const PRIVACY = {
  marta: { profileVisibility: 'friends', friendRequests: 'everyone' },
  alvaro: { profileVisibility: 'everyone', friendRequests: 'nobody' },
  irene: { profileVisibility: 'everyone', friendRequests: 'friends_of_friends' },
  lucia: { profileVisibility: 'everyone', friendRequests: 'everyone' },
  hugo: { profileVisibility: 'everyone', friendRequests: 'everyone' },
  // Public accounts that hide part of their location.
  claudia: { cityVisibility: 'only_me' },
  oscar: { distanceVisibility: 'friends' },
  bea: { profileVisibility: 'friends', friendRequests: 'friends_of_friends' },
}

const VISITS = { carlos: 1284, ana: 2310, pablo: 856, laura: 1942, javi: 634, sara: 1107, miguel: 978 }

const id = (key) => `u_${key}`

export const buildSeed = () => {
  const profiles = PEOPLE.map(([key, firstName, lastName, avatarUrl, city, bio, birthday, studies, work], i) => ({
    id: id(key),
    firstName,
    lastName,
    avatarUrl,
    coverUrl: photoUrl(`cover-${key}`, 1500, 500),
    city,
    cityLat: CITY_COORDS[city]?.[0] ?? null,
    cityLng: CITY_COORDS[city]?.[1] ?? null,
    bio,
    birthday,
    studies,
    work,
    // Visits other people have made to the profile over the years.
    visitCount: VISITS[key] ?? 40 + i * 17,
    createdAt: ago({ d: 1500 - i * 40 }),
  }))

  const users = PEOPLE.map(([key], i) => ({
    id: id(key),
    email: `${key}@demo.youngrr.app`,
    passwordHash: null,
    salt: null,
    createdAt: ago({ d: 1500 - i * 40 }),
  }))

  const settings = Object.fromEntries(
    PEOPLE.map(([key]) => [
      id(key),
      {
        privacy: { profileVisibility: 'everyone', cityVisibility: 'everyone', distanceVisibility: 'everyone', friendRequests: 'everyone', ...PRIVACY[key] },
        notifications: { grr: true, comments: true, friendRequests: true, events: true, messages: true, tags: true },
        appearance: { theme: 'system' },
        nearby: { radiusKm: NEARBY_DEFAULT_RADIUS_KM },
      },
    ]),
  )

  const friendships = FRIENDS.map(([a, b, days]) => {
    const [x, y] = [id(a), id(b)].sort()
    return { userA: x, userB: y, createdAt: ago({ d: days }) }
  })

  const friendRequests = [
    { id: 'fr_1', fromId: id('miguel'), toId: id('carlos'), status: 'pending', createdAt: ago({ h: 3 }), respondedAt: null },
    { id: 'fr_2', fromId: id('carlos'), toId: id('lucia'), status: 'pending', createdAt: ago({ d: 2 }), respondedAt: null },
    { id: 'fr_3', fromId: id('diego'), toId: id('ana'), status: 'pending', createdAt: ago({ d: 1 }), respondedAt: null },
  ]

  // ---- Albums & photos ----------------------------------------------------

  const albums = []
  const photos = []

  const album = (key, owner, title, description, createdAt, kind = 'user') => {
    albums.push({ id: `a_${key}`, ownerId: id(owner), kind, title, description, coverPhotoId: null, createdAt, updatedAt: createdAt })
    return `a_${key}`
  }

  const photo = (key, owner, albumId, caption, createdAt, [w, h] = [1200, 800]) => {
    photos.push({ id: `ph_${key}`, ownerId: id(owner), albumId, url: photoUrl(key, w, h), width: w, height: h, caption, createdAt })
    return `ph_${key}`
  }

  const wall = {}
  for (const key of ['carlos', 'ana', 'pablo', 'laura', 'javi', 'sara', 'miguel', 'nerea', 'hugo', 'ruben', 'bea']) {
    wall[key] = album(`wall_${key}`, key, 'Fotos del muro', 'Fotografías publicadas en el muro.', ago({ d: 300 }), 'wall')
  }

  const verano = album('verano', 'carlos', 'Verano 2026', 'Semana en Comillas con la cuadrilla. Sol, playa y cero cobertura.', ago({ d: 40 }))
  const veranoCaptions = ['Llegada a Comillas', 'La playa para nosotros solos', 'Atardecer desde el faro', 'Pablo y la sombrilla, una historia de amor', 'Cena en la terraza', 'Último baño', 'El grupo al completo', 'Vuelta a casa', 'Nos quedamos sin hielo']
  veranoCaptions.forEach((c, i) => photo(`verano-${i + 1}`, 'carlos', verano, c, ago({ d: 40 - i, h: i }), i % 3 === 1 ? [800, 1100] : [1200, 800]))

  const cumple = album('cumple-ana', 'carlos', 'Cumpleaños de Ana', '25 velas y ni una se apagó a la primera.', ago({ d: 20 }))
  ;['Sorpresa', 'La tarta', 'Brindis', 'Karaoke a las 3', 'Foto de grupo', 'El after'].forEach((c, i) =>
    photo(`cumple-${i + 1}`, 'carlos', cumple, c, ago({ d: 20, h: 6 - i })),
  )

  const viajes = album('viajes', 'carlos', 'Viajes', 'Lisboa, Oporto y alguna escapada más.', ago({ d: 200 }))
  ;['Tranvía 28', 'Miradouro de Santa Luzia', 'Pastéis de Belém', 'Ribeira de Oporto', 'Puente Don Luis I', 'Librería Lello (con cola)', 'Picos de Europa', 'Refugio a 2.000 metros'].forEach((c, i) =>
    photo(`viajes-${i + 1}`, 'carlos', viajes, c, ago({ d: 200 - i * 12 }), i % 4 === 2 ? [800, 1100] : [1200, 800]),
  )

  const lisboa = album('lisboa', 'ana', 'Nos vamos a Lisboa', 'Cinco días, cuatro amigas y demasiados pastéis.', ago({ d: 6 }))
  ;['Aeropuerto a las 6 am', 'Alfama', 'Atardecer en el río', 'Barrio Alto', 'Fado', 'Última cena'].forEach((c, i) =>
    photo(`lisboa-${i + 1}`, 'ana', lisboa, c, ago({ d: 6 - i * 0.5 })),
  )

  const fiestas = album('fiestas', 'laura', 'Semana Grande', 'Fuegos, conciertos y verbena en la campa.', ago({ d: 50 }))
  ;['Fuegos desde Puertochico', 'Concierto en la campa', 'La noria', 'Verbena', 'Churros a las 5'].forEach((c, i) =>
    photo(`fiestas-${i + 1}`, 'laura', fiestas, c, ago({ d: 50 - i, h: 2 })),
  )

  const retratos = album('retratos', 'irene', 'Retratos', 'Proyecto de retrato en blanco y negro.', ago({ d: 30 }))
  ;['Retrato I', 'Retrato II', 'Retrato III', 'Retrato IV'].forEach((c, i) =>
    photo(`retratos-${i + 1}`, 'irene', retratos, c, ago({ d: 30 - i }), [900, 1200]),
  )

  const pabloSurf = album('pablo-futbol', 'pablo', 'Liga de los domingos', 'Temporada 2026 del equipo.', ago({ d: 90 }))
  ;['Pretemporada', 'Primer partido', 'Celebración', 'Cena de equipo'].forEach((c, i) =>
    photo(`futbol-${i + 1}`, 'pablo', pabloSurf, c, ago({ d: 90 - i * 7 })),
  )

  const piso = album('sara-piso', 'sara', 'Mi primer piso en Madrid', 'La inauguración con los de Santander.', ago({ d: 4 }))
  ;['El salón (casi) montado', 'Cena de inauguración', 'Vistas desde la ventana'].forEach((c, i) =>
    photo(`piso-${i + 1}`, 'sara', piso, c, ago({ d: 4, h: 3 - i })),
  )

  albums.find((a) => a.id === verano).coverPhotoId = 'ph_verano-3'
  albums.find((a) => a.id === cumple).coverPhotoId = 'ph_cumple-5'

  for (const album of albums) {
    const newest = photos.filter((p) => p.albumId === album.id).reduce((max, p) => (p.createdAt > max ? p.createdAt : max), album.createdAt)
    album.updatedAt = newest
  }

  // ---- Statuses and album uploads ------------------------------------------
  // No free posts: each person has one status (a short phrase) and uploading
  // photos to an album shows up in the friends' news.

  const S = (author, text, createdAt) => ({ id: `p_estado-${author}`, authorId: id(author), kind: 'status', text, photoId: null, createdAt, updatedAt: null })
  const U = (key, author, albumId, photoIds, createdAt) => ({
    id: `p_up-${key}`, authorId: id(author), kind: 'album_upload', albumId, photoIds, text: '', photoId: null, createdAt, updatedAt: null,
  })
  const range = (prefix, n) => Array.from({ length: n }, (_, i) => `ph_${prefix}-${i + 1}`)

  const posts = [
    S('carlos', 'Cena de fin de verano el viernes. Os he mandado invitación, no me falléis', ago({ d: 6, h: 4 })),
    S('ana', 'Contando las horas para Lisboa ✈️', ago({ h: 7 })),
    S('pablo', 'Mañana partido a las 11 en La Albericia. Nos faltan dos, ¿quién se apunta?', ago({ h: 4 })),
    S('laura', 'Modo exámenes activado. No me habléis hasta el viernes', ago({ d: 1, h: 6 })),
    S('sara', 'Ya queda menos para mi cumple. Guardad el sábado, que os quiero a todos en casa', ago({ d: 1, h: 1 })),
    S('javi', 'Nuevo récord en el Sardinero: 10 km en 48 minutos. Mañana no me puedo mover', ago({ d: 1, h: 3 })),
    S('miguel', 'Tocamos el viernes en el Kafe Antzokia. Venid!!', ago({ d: 2, h: 5 })),
    S('nerea', 'Mercadillo de segunda mano el sábado en la plaza de Pombo. ¿Alguien se anima a montar puesto?', ago({ h: 1 })),
    S('hugo', 'Atardecer en la playa de Laredo. No hay filtro que mejore esto 🌅', ago({ h: 5 })),
    S('claudia', 'Buscamos voces para el coro de Comillas. Ensayamos los jueves a las 20:00', ago({ d: 1, h: 2 })),
    S('oscar', '¿Alguien de Castro que juegue al pádel? Nos falta uno para el domingo', ago({ d: 2, h: 3 })),
    S('bea', 'Esto solo lo ven mis amigos', ago({ h: 3 })),
    S('ruben', 'Primera nevada en Alto Campoo ❄️', ago({ h: 4 })),
    U('lisboa', 'ana', lisboa, range('lisboa', 6), ago({ h: 20 })),
    U('piso', 'sara', piso, range('piso', 3), ago({ d: 4, h: 1 })),
    U('cumple', 'carlos', cumple, range('cumple', 6), ago({ d: 20 })),
  ]

  // ---- Comments -----------------------------------------------------------

  let commentSeq = 0
  const comments = []
  const C = (targetType, targetId, author, text, createdAt) =>
    comments.push({ id: `c_${++commentSeq}`, targetType, targetId, authorId: id(author), text, createdAt })

  C('post', 'p_estado-carlos', 'ana', 'Ahí estaré!!', ago({ d: 5 }))
  C('post', 'p_estado-carlos', 'pablo', 'Llevo yo el postre', ago({ m: 30 }))
  C('post', 'p_up-lisboa', 'laura', 'Traedme pastéis de nata o no volváis', ago({ h: 18 }))
  C('post', 'p_up-lisboa', 'sara', 'Qué envidia!! Pasadlo genial', ago({ h: 12 }))
  C('post', 'p_estado-pablo', 'javi', 'Cuenta conmigo', ago({ h: 3, m: 40 }))
  C('post', 'p_estado-pablo', 'carlos', 'Yo voy, pero de defensa que la última vez...', ago({ h: 3 }))
  C('post', 'p_estado-sara', 'laura', 'Ahí estaremos!!', ago({ d: 1 }))
  C('post', 'p_estado-javi', 'carlos', 'Máquina. El año que viene la media maratón', ago({ d: 1, h: 2 }))
  C('post', 'p_up-piso', 'ana', 'Qué piso más bonito', ago({ d: 3, h: 22 }))
  C('post', 'p_up-piso', 'laura', 'Mucha suerte en Madrid, Sara', ago({ d: 3, h: 21 }))
  C('post', 'p_estado-nerea', 'laura', 'Yo llevo discos, guardadme sitio', ago({ m: 40 }))
  C('post', 'p_estado-hugo', 'hugo', 'Mañana a la misma hora, quien quiera venir', ago({ h: 4 }))
  C('photo', 'ph_verano-3', 'laura', 'Esta foto es de postal', ago({ d: 35 }))
  C('photo', 'ph_verano-3', 'ana', 'Fondo de pantalla ya', ago({ d: 34 }))
  C('photo', 'ph_cumple-5', 'ana', 'Os quiero mucho 🥹', ago({ d: 19 }))
  C('photo', 'ph_cumple-2', 'pablo', 'La tarta más buena del mundo', ago({ d: 19 }))
  C('photo', 'ph_lisboa-3', 'carlos', 'Qué luz', ago({ d: 4 }))

  // ---- Grrs ---------------------------------------------------------------

  let grrSeq = 0
  const grrs = []
  const G = (targetType, targetId, users, createdAt) =>
    users.forEach((u) => grrs.push({ id: `g_${++grrSeq}`, userId: id(u), targetType, targetId, createdAt }))

  G('post', 'p_estado-carlos', ['ana', 'pablo', 'laura'], ago({ m: 10 }))
  G('post', 'p_up-lisboa', ['carlos', 'laura', 'sara', 'irene'], ago({ h: 15 }))
  G('post', 'p_estado-pablo', ['javi'], ago({ h: 3 }))
  G('post', 'p_estado-sara', ['ana', 'laura', 'miguel'], ago({ d: 1 }))
  G('post', 'p_estado-javi', ['pablo', 'miguel'], ago({ d: 1 }))
  G('post', 'p_estado-miguel', ['javi', 'sara', 'diego'], ago({ d: 2 }))
  G('post', 'p_up-piso', ['ana', 'laura', 'carlos', 'miguel'], ago({ d: 3 }))
  G('post', 'p_estado-nerea', ['laura', 'bea'], ago({ m: 30 }))
  G('post', 'p_estado-hugo', ['claudia', 'oscar', 'nerea'], ago({ h: 3 }))
  G('post', 'p_estado-claudia', ['nerea'], ago({ d: 1 }))
  G('photo', 'ph_verano-3', ['laura', 'ana', 'pablo'], ago({ d: 1 }))
  G('photo', 'ph_cumple-5', ['ana', 'sara'], ago({ d: 19 }))
  G('photo', 'ph_lisboa-3', ['carlos', 'sara'], ago({ d: 4 }))
  G('photo', 'ph_fiestas-1', ['carlos'], ago({ d: 45 }))

  // ---- Photo tags ---------------------------------------------------------

  const photoTags = [
    { id: 't_1', photoId: 'ph_cumple-5', userId: id('ana'), taggedBy: id('carlos'), x: 0.42, y: 0.38, createdAt: ago({ d: 19 }) },
    { id: 't_2', photoId: 'ph_cumple-5', userId: id('laura'), taggedBy: id('carlos'), x: 0.68, y: 0.42, createdAt: ago({ d: 19 }) },
    { id: 't_3', photoId: 'ph_verano-4', userId: id('pablo'), taggedBy: id('carlos'), x: 0.5, y: 0.45, createdAt: ago({ d: 36 }) },
    { id: 't_4', photoId: 'ph_lisboa-4', userId: id('carlos'), taggedBy: id('ana'), x: 0.35, y: 0.5, createdAt: ago({ d: 2 }) },
    { id: 't_5', photoId: 'ph_verano-7', userId: id('ana'), taggedBy: id('carlos'), x: 0.3, y: 0.4, createdAt: ago({ d: 34 }) },
    { id: 't_6', photoId: 'ph_verano-7', userId: id('javi'), taggedBy: id('carlos'), x: 0.7, y: 0.42, createdAt: ago({ d: 34 }) },
    // A friend tags Carlos in a photo she uploaded.
    { id: 't_7', photoId: 'ph_piso-2', userId: id('carlos'), taggedBy: id('sara'), x: 0.5, y: 0.4, createdAt: ago({ d: 3 }) },
  ]

  // ---- Profile walls (tablón) --------------------------------------------

  let wallSeq = 0
  const W = (profile, author, text, createdAt) => ({ id: `w_${++wallSeq}`, profileId: id(profile), authorId: id(author), text, createdAt })
  const wallMessages = [
    W('carlos', 'ana', 'Ya he visto las fotos de Comillas. ¿Cuándo repetimos? 😎', ago({ h: 1, m: 20 })),
    W('carlos', 'laura', 'Feliz semana! Nos vemos el viernes en la cena', ago({ d: 1, h: 3 })),
    W('carlos', 'pablo', 'Me debes una revancha al futbolín', ago({ d: 4 })),
    W('ana', 'carlos', 'Pásalo genial en Lisboa!!', ago({ m: 18 })),
    W('ana', 'sara', 'Te echo de menos, a ver si vienes pronto a Madrid', ago({ d: 2 })),
    W('laura', 'javi', 'Gracias por los apuntes, te debo un café', ago({ d: 3 })),
  ]

  // ---- Co-owned photos ---------------------------------------------------

  const photoOwners = [
    // Laura's concert photo, shared with Carlos: both own it.
    { photoId: 'ph_fiestas-2', userId: id('carlos'), status: 'accepted', invitedBy: id('laura'), createdAt: ago({ d: 49 }), respondedAt: ago({ d: 49 }) },
    // Ana wants to share a Lisbon photo with Carlos; he has not answered yet.
    { photoId: 'ph_lisboa-3', userId: id('carlos'), status: 'pending', invitedBy: id('ana'), createdAt: ago({ h: 2 }), respondedAt: null },
  ]

  // ---- Events -------------------------------------------------------------

  const E = (key, creator, title, description, date, time, location, createdAt) => ({
    id: `e_${key}`, creatorId: id(creator), title, description, imageUrl: photoUrl(`event-${key}`, 1200, 600), date, time, location, createdAt, updatedAt: createdAt,
  })

  const events = [
    E('cena', 'carlos', 'Cena de fin de verano', 'Despedimos el verano como se merece. Reservado para 10, confirmad antes del jueves para avisar al restaurante.', inDays(4), '21:30', 'La Bodeguilla, calle del Sol 12, Santander', ago({ d: 6, h: 4 })),
    E('cumple-sara', 'sara', 'Cumple de Sara', 'Celebramos mis 25 en casa. Traed hambre y buena música. Si venís de fuera hay sofá.', inDays(12), '22:00', 'Casa de Sara, Sardinero', ago({ d: 1, h: 2 })),
    E('partido', 'pablo', 'Partido del domingo', 'Pachanga de siempre. Traed peto blanco y peto azul.', inDays(2), '11:00', 'Campo de La Albericia', ago({ h: 4 })),
    E('concierto', 'laura', 'Concierto en la campa', 'Semana Grande, grupo local y verbena después.', toDateInput(new Date(Date.now() - 45 * DAY)), '22:30', 'Campa de La Magdalena', ago({ d: 60 })),
  ]

  const M = (event, user, status, invitedBy, respondedAt = null) => ({ eventId: `e_${event}`, userId: id(user), status, invitedBy: id(invitedBy), respondedAt })

  const eventMembers = [
    M('cena', 'carlos', 'going', 'carlos', ago({ d: 6 })),
    M('cena', 'ana', 'going', 'carlos', ago({ d: 5 })),
    M('cena', 'pablo', 'maybe', 'carlos', ago({ d: 5 })),
    M('cena', 'laura', 'going', 'carlos', ago({ d: 4 })),
    M('cena', 'javi', 'pending', 'carlos'),
    M('cena', 'sara', 'declined', 'carlos', ago({ d: 3 })),
    M('cumple-sara', 'sara', 'going', 'sara', ago({ d: 1 })),
    M('cumple-sara', 'carlos', 'pending', 'sara'),
    M('cumple-sara', 'ana', 'going', 'sara', ago({ h: 20 })),
    M('cumple-sara', 'laura', 'going', 'sara', ago({ h: 18 })),
    M('cumple-sara', 'miguel', 'maybe', 'sara', ago({ h: 10 })),
    M('partido', 'pablo', 'going', 'pablo', ago({ h: 4 })),
    M('partido', 'carlos', 'going', 'pablo', ago({ h: 3 })),
    M('partido', 'javi', 'going', 'pablo', ago({ h: 3 })),
    M('concierto', 'laura', 'going', 'laura', ago({ d: 60 })),
    M('concierto', 'carlos', 'going', 'laura', ago({ d: 58 })),
    M('concierto', 'ana', 'going', 'laura', ago({ d: 58 })),
  ]

  // ---- Messages -----------------------------------------------------------

  const conversations = []
  const conversationMembers = []
  const messages = []
  let msgSeq = 0

  const conversation = (key, other, lines, carlosReadAt) => {
    const convId = `cv_${key}`
    const last = lines[lines.length - 1][2]
    conversations.push({ id: convId, memberIds: [id('carlos'), id(other)], createdAt: lines[0][2], updatedAt: last })
    conversationMembers.push({ conversationId: convId, userId: id('carlos'), lastReadAt: carlosReadAt })
    conversationMembers.push({ conversationId: convId, userId: id(other), lastReadAt: last })
    lines.forEach(([sender, text, createdAt]) =>
      messages.push({ id: `m_${++msgSeq}`, conversationId: convId, senderId: id(sender), text, createdAt }),
    )
  }

  conversation('ana', 'ana', [
    ['carlos', '¿Al final te vienes a la cena del viernes?', ago({ h: 3 })],
    ['ana', 'Sí!! Ya he confirmado en el evento', ago({ h: 2, m: 50 })],
    ['carlos', 'Genial. Laura también viene', ago({ h: 2, m: 45 })],
    ['ana', '¿A qué hora quedamos?', ago({ m: 40 })],
  ], ago({ h: 2, m: 45 }))

  conversation('pablo', 'pablo', [
    ['carlos', 'Oye, ¿se juega este finde?', ago({ h: 6 })],
    ['pablo', 'Mañana hay partido.', ago({ h: 5 })],
    ['carlos', 'Perfecto, allí estaré', ago({ h: 4, m: 55 })],
  ], ago({ h: 4, m: 55 }))

  conversation('laura', 'laura', [
    ['carlos', 'Pásame las fotos de la Semana Grande cuando puedas', ago({ d: 1 })],
    ['laura', 'Claro, esta noche las subo', ago({ d: 1 })],
    ['laura', 'Te he enviado las fotos.', ago({ h: 1 })],
  ], ago({ d: 1 }))

  conversation('javi', 'javi', [
    ['javi', 'Gracias por aceptar!! A ver cuándo corremos juntos', ago({ d: 7 })],
    ['carlos', 'Cuando quieras, pero a mi ritmo 😅', ago({ d: 7 })],
  ], ago({ d: 7 }))

  // ---- Notifications ------------------------------------------------------

  let nSeq = 0
  const N = (type, actor, targetId, createdAt, read = false) => ({
    id: `n_${++nSeq}`, userId: id('carlos'), actorId: id(actor), type, targetId, createdAt, readAt: read ? createdAt : null,
  })

  const notifications = [
    N('grr_post', 'ana', 'p_estado-carlos', ago({ m: 10 })),
    N('wall_message', 'ana', id('carlos'), ago({ h: 1, m: 20 })),
    N('comment_post', 'pablo', 'p_estado-carlos', ago({ m: 30 })),
    N('grr_post', 'pablo', 'p_estado-carlos', ago({ m: 12 })),
    N('comment_photo', 'ana', 'ph_cumple-5', ago({ h: 5 })),
    N('grr_photo', 'laura', 'ph_verano-3', ago({ d: 1 }), true),
    N('photo_tag', 'ana', 'ph_lisboa-4', ago({ d: 2 }), true),
    N('photo_tag', 'sara', 'ph_piso-2', ago({ d: 3 })),
    N('comment_post', 'ana', 'p_estado-carlos', ago({ d: 5 }), true),
    N('friend_accepted', 'javi', id('javi'), ago({ d: 7 }), true),
  ]

  return {
    version: 1,
    users,
    profiles,
    settings,
    friendships,
    friendRequests,
    posts,
    comments,
    grrs,
    photos,
    albums,
    photoTags,
    photoOwners,
    events,
    eventMembers,
    conversations,
    conversationMembers,
    messages,
    notifications,
    profileVisits: [],
    wallMessages,
    hiddenPosts: [],
    reports: [],
  }
}

/** Accounts offered on the login screen while running on the local backend. */
export const DEMO_ACCOUNT_IDS = ['u_carlos', 'u_ana', 'u_pablo', 'u_laura', 'u_javi', 'u_sara', 'u_miguel']
