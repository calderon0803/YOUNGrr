// Place groups of YOUNGrr: the autonomous communities of Spain and their
// provinces (a community of a single province, like Cantabria, is one group).
// Same keys as the place_groups migration. Municipalities are not listed: they
// are activated on demand (see PLACE_GROUPS in config/app.js).
// `aliases` are other names the geocoder (OpenStreetMap) may give them, used to
// find the province or community of a town.

const P = (key, name, aliases = []) => ({ key, name, aliases })

export const PLACES = [
  { ...P('es-andalucia', 'Andalucía'), provinces: [P('es-almeria', 'Almería'), P('es-cadiz', 'Cádiz'), P('es-cordoba', 'Córdoba'), P('es-granada', 'Granada'), P('es-huelva', 'Huelva'), P('es-jaen', 'Jaén'), P('es-malaga', 'Málaga'), P('es-sevilla', 'Sevilla')] },
  { ...P('es-aragon', 'Aragón'), provinces: [P('es-huesca', 'Huesca', ['Uesca']), P('es-teruel', 'Teruel'), P('es-zaragoza', 'Zaragoza')] },
  P('es-asturias', 'Asturias', ['Principado de Asturias']),
  P('es-baleares', 'Illes Balears', ['Islas Baleares', 'Baleares']),
  { ...P('es-canarias', 'Canarias'), provinces: [P('es-las-palmas', 'Las Palmas'), P('es-santa-cruz-de-tenerife', 'Santa Cruz de Tenerife')] },
  P('es-cantabria', 'Cantabria'),
  { ...P('es-castilla-la-mancha', 'Castilla-La Mancha'), provinces: [P('es-albacete', 'Albacete'), P('es-ciudad-real', 'Ciudad Real'), P('es-cuenca', 'Cuenca'), P('es-guadalajara', 'Guadalajara'), P('es-toledo', 'Toledo')] },
  { ...P('es-castilla-y-leon', 'Castilla y León'), provinces: [P('es-avila', 'Ávila'), P('es-burgos', 'Burgos'), P('es-leon', 'León'), P('es-palencia', 'Palencia'), P('es-salamanca', 'Salamanca'), P('es-segovia', 'Segovia'), P('es-soria', 'Soria'), P('es-valladolid', 'Valladolid'), P('es-zamora', 'Zamora')] },
  { ...P('es-cataluna', 'Cataluña', ['Catalunya']), provinces: [P('es-barcelona', 'Barcelona'), P('es-girona', 'Girona', ['Gerona']), P('es-lleida', 'Lleida', ['Lérida']), P('es-tarragona', 'Tarragona')] },
  P('es-ceuta', 'Ceuta', ['Ciudad Autónoma de Ceuta']),
  { ...P('es-comunitat-valenciana', 'Comunitat Valenciana', ['Comunidad Valenciana']), provinces: [P('es-alicante', 'Alicante', ['Alacant']), P('es-castellon', 'Castellón', ['Castelló']), P('es-valencia', 'Valencia', ['València'])] },
  { ...P('es-extremadura', 'Extremadura'), provinces: [P('es-badajoz', 'Badajoz'), P('es-caceres', 'Cáceres')] },
  { ...P('es-galicia', 'Galicia'), provinces: [P('es-a-coruna', 'A Coruña', ['La Coruña']), P('es-lugo', 'Lugo'), P('es-ourense', 'Ourense', ['Orense']), P('es-pontevedra', 'Pontevedra')] },
  P('es-madrid', 'Comunidad de Madrid', ['Madrid']),
  P('es-melilla', 'Melilla', ['Ciudad Autónoma de Melilla']),
  P('es-murcia', 'Región de Murcia', ['Murcia']),
  P('es-navarra', 'Navarra', ['Comunidad Foral de Navarra', 'Nafarroa']),
  { ...P('es-pais-vasco', 'País Vasco', ['Euskadi', 'País Vasco / Euskadi']), provinces: [P('es-alava', 'Álava', ['Araba', 'Araba/Álava']), P('es-bizkaia', 'Bizkaia', ['Vizcaya']), P('es-gipuzkoa', 'Gipuzkoa', ['Guipúzcoa'])] },
  P('es-la-rioja', 'La Rioja'),
]
