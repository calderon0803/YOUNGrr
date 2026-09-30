// A small catalogue for the demo (and when there is no TMDB key): the same shape
// as catalog.service.js returns. No images, so nothing is loaded from outside.

const M = (id, title, year) => ({ source: 'tmdb', externalId: String(id), title, year, imagePath: null, detail: String(year) })
const A = (id, title, detail) => ({ source: 'musicbrainz', externalId: id, title, year: null, imagePath: null, detail })

export const SAMPLE_CATALOG = {
  movie: [
    M(438631, 'Dune', 2021),
    M(693134, 'Dune: parte dos', 2024),
    M(603, 'Matrix', 1999),
    M(155, 'El caballero oscuro', 2008),
    M(496243, 'Parásitos', 2019),
    M(1417, 'El laberinto del fauno', 2006),
    M(13, 'Forrest Gump', 1994),
    M(680, 'Pulp Fiction', 1994),
    M(372058, 'Your Name', 2016),
    M(129, 'El viaje de Chihiro', 2001),
  ],
  series: [
    M(1399, 'Juego de tronos', 2011),
    M(1396, 'Breaking Bad', 2008),
    M(71446, 'La casa de papel', 2017),
    M(66732, 'Stranger Things', 2016),
    M(70523, 'Dark', 2017),
    M(1668, 'Friends', 1994),
    M(76479, 'The Boys', 2019),
    M(100088, 'The Last of Us', 2023),
  ],
  artist: [
    A('mb-vetusta', 'Vetusta Morla', 'España'),
    A('mb-rosalia', 'Rosalía', 'España'),
    A('mb-leiva', 'Leiva', 'España'),
    A('mb-arctic', 'Arctic Monkeys', 'Reino Unido'),
    A('mb-coldplay', 'Coldplay', 'Reino Unido'),
    A('mb-bad-bunny', 'Bad Bunny', 'Puerto Rico'),
    A('mb-izal', 'Izal', 'España'),
    A('mb-taylor', 'Taylor Swift', 'Estados Unidos'),
  ],
}
