// A short selection of common emojis for the picker (chat, status, comments).
// The interface never shows emojis of its own: these are only for what people
// write. Each one has a Spanish name for screen readers.
export const EMOJIS = [
  ['😀', 'Sonrisa'], ['😃', 'Sonrisa grande'], ['😄', 'Sonrisa con ojos felices'], ['😁', 'Sonrisa radiante'],
  ['😆', 'Risa'], ['😅', 'Risa con sudor'], ['😂', 'Lágrimas de risa'], ['🤣', 'Muerto de risa'],
  ['😊', 'Carita feliz'], ['🙂', 'Sonrisa leve'], ['😉', 'Guiño'], ['😇', 'Angelito'],
  ['😍', 'Enamorado'], ['🥰', 'Con corazones'], ['😘', 'Beso'], ['😋', 'Qué rico'],
  ['😜', 'Guiño con lengua'], ['🤪', 'Loco'], ['😎', 'Con gafas de sol'], ['🤩', 'Alucinado'],
  ['🥳', 'De fiesta'], ['🤗', 'Abrazo'], ['🤔', 'Pensando'], ['🤨', 'Ceja levantada'],
  ['😐', 'Sin expresión'], ['😏', 'Sonrisa pícara'], ['🙄', 'Ojos en blanco'], ['😬', 'Mueca'],
  ['🤭', 'Tapándose la boca'], ['🤫', 'Silencio'], ['😴', 'Durmiendo'], ['🤤', 'Babeando'],
  ['😷', 'Con mascarilla'], ['🤒', 'Enfermo'], ['🥵', 'Con calor'], ['🥶', 'Con frío'],
  ['🤯', 'Cabeza explotando'], ['😱', 'Grito de miedo'], ['😳', 'Sonrojado'], ['🥺', 'Suplicando'],
  ['😢', 'Llorando'], ['😭', 'Llorando a mares'], ['😞', 'Decepcionado'], ['😤', 'Resoplando'],
  ['😡', 'Enfadado'], ['🙃', 'Al revés'], ['👀', 'Ojos'], ['💩', 'Caca'],
  ['👍', 'Pulgar arriba'], ['👎', 'Pulgar abajo'], ['👏', 'Aplausos'], ['🙌', 'Manos arriba'],
  ['🙏', 'Por favor'], ['💪', 'Fuerza'], ['🤝', 'Apretón de manos'], ['👋', 'Saludo'],
  ['✌️', 'Victoria'], ['🤞', 'Dedos cruzados'], ['👌', 'Perfecto'], ['🤙', 'Llámame'],
  ['❤️', 'Corazón rojo'], ['🧡', 'Corazón naranja'], ['💛', 'Corazón amarillo'], ['💚', 'Corazón verde'],
  ['💙', 'Corazón azul'], ['💜', 'Corazón morado'], ['🖤', 'Corazón negro'], ['💔', 'Corazón roto'],
  ['🔥', 'Fuego'], ['✨', 'Destellos'], ['🎉', 'Confeti'], ['🎂', 'Tarta de cumpleaños'],
  ['🍻', 'Brindis'], ['🍕', 'Pizza'], ['☕', 'Café'], ['⚽', 'Fútbol'],
  ['🎵', 'Música'], ['📸', 'Cámara'], ['☀️', 'Sol'], ['🌧️', 'Lluvia'],
  ['🏖️', 'Playa'], ['✈️', 'Avión'], ['🚗', 'Coche'], ['💯', 'Cien'],
].map(([emoji, name]) => ({ emoji, name }))
