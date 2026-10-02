# Registro de actividades de tratamiento

Artículo 30 del RGPD. Versión del 1 de octubre de 2026. **Borrador para revisar.**

## Responsable

- **Responsable:** Carlos Calderón (persona física). NIF y domicilio: los de `LEGAL` en `src/config/app.js`.
- **Contacto:** calderon0803+youngrr@gmail.com
- **Delegado de protección de datos:** no se ha nombrado. No es obligatorio: no es una autoridad pública
  y su actividad principal no es la observación sistemática a gran escala ni el tratamiento a gran
  escala de categorías especiales (art. 37 RGPD, art. 34 LOPDGDD). Revisarlo si YOUNGrr crece mucho.

Medidas de seguridad comunes a todos los tratamientos: ver el apartado final.

---

## 1. Cuentas y perfiles

- **Finalidad:** crear y mantener la cuenta y el perfil; comprobar la mayoría de edad.
- **Base jurídica:** ejecución del contrato (condiciones de uso), art. 6.1.b RGPD. La comprobación de
  edad, interés legítimo y obligación de no prestar el servicio a menores (art. 6.1.f).
- **Interesados:** personas usuarias.
- **Datos:** correo, contraseña (solo su hash, en Supabase Auth), nombre y apellido, foto de perfil y
  portada, ciudad o pueblo (solo el nombre), presentación, cumpleaños, estudios, trabajo, confirmación
  de mayoría de edad (no la fecha de nacimiento), versión de las condiciones aceptada y fecha,
  contador de visitas, ajustes de privacidad y avisos.
- **Destinatarios:** Supabase (encargado). Lo que se ve de cada perfil, según sus ajustes.
- **Transferencias internacionales:** no (Supabase en la UE, región `eu-west-1`, Irlanda). Ver el documento de encargados.
- **Plazo:** mientras exista la cuenta; se borra al eliminarla.

## 2. Contenido y relaciones

- **Finalidad:** prestar la red social: estados, fotos y álbumes, etiquetas, comentarios, Grr, tablón,
  mensajes privados y chats de grupo, amistades, bloqueos, eventos, grupos y su Gallinero, menciones,
  peticiones de grupos de pueblos, gustos (artistas, películas y series con estrellas), logros, experiencia y nivel.
- **Base jurídica:** ejecución del contrato (art. 6.1.b).
- **Interesados:** personas usuarias, y terceros que aparecen en fotos o textos que suben otras personas.
- **Datos:** el contenido publicado y sus metadatos (fecha, autor, destinatarios), relaciones y
  preferencias de privacidad de cada grupo.
- **Destinatarios:** Supabase (encargado). Las personas a las que cada usuario lo muestra.
  Si un estado lleva un enlace de Spotify, al publicarlo el navegador envía el enlace y la IP a Spotify, y las
  portadas se cargan desde Spotify.
  Al buscar en los catálogos, el navegador envía el texto buscado y la IP a TMDB y MusicBrainz, y al
  elegir pueblo a OpenStreetMap (Nominatim); no son encargados: el navegador les hace la petición
  directamente y no reciben la cuenta.
- **Transferencias internacionales:** las búsquedas de catálogo van a EE. UU. (TMDB, MusicBrainz).
- **Plazo:** hasta que el usuario lo borre o elimine la cuenta; plazos menores en la política de
  privacidad (por ejemplo, grupos vacíos a los 7 días y peticiones de pueblos a los 90).

## 3. Invitaciones

- **Finalidad:** el registro solo con invitación.
- **Base jurídica:** ejecución del contrato (art. 6.1.b) para quien invita; interés legítimo para la
  persona invitada (no se guardan sus datos hasta que crea la cuenta).
- **Datos:** enlace aleatorio, quién lo creó, cuándo y quién lo usó.
- **Plazo:** los enlaces sin usar, al caducar (30 días).

## 4. Moderación, reportes y avisos de contenido ilegal

- **Finalidad:** revisar reportes y avisos de contenido ilegal (DSA, art. 16), retirar contenido,
  motivarlo (art. 17), tramitar apelaciones y, si procede, comunicar delitos (art. 18).
- **Base jurídica:** obligación legal (art. 6.1.c, Reglamento de Servicios Digitales) e interés
  legítimo en mantener una red segura (art. 6.1.f).
- **Interesados:** quien reporta o avisa, la persona reportada, terceros que aparecen en el contenido.
- **Datos:** quién reporta, el motivo, la explicación, una copia del contenido; en los avisos por
  correo, nombre y correo de quien avisa; la decisión, la norma aplicada y la apelación.
- **Destinatarios:** las personas moderadoras de YOUNGrr. Autoridades cuando la ley lo exija.
- **Plazo:** reportes revisados, un año desde la decisión; reportes que no llegan al mínimo, 90 días;
  copia de lo retirado, 14 días o hasta resolver la apelación; avisos por correo, un año desde que se
  resuelven.

## 5. Seguridad y prevención de abusos

- **Finalidad:** frenar el spam y los abusos y que el servicio funcione.
- **Base jurídica:** interés legítimo (art. 6.1.f).
- **Datos:** recuento de acciones por minuto (se borra en una hora), marca cifrada de visita a un
  perfil (se borra a las 6 horas), registros técnicos de los proveedores (IP, fecha, navegador).
- **Plazo:** los indicados; los registros técnicos, según los ciclos de Supabase y Netlify.

## 6. Ejercicio de derechos y contacto

- **Finalidad:** atender solicitudes de acceso, rectificación, supresión, oposición, limitación y
  portabilidad, y otras consultas.
- **Base jurídica:** obligación legal (art. 6.1.c).
- **Datos:** los de la solicitud y la respuesta.
- **Plazo:** lo necesario para atenderla y acreditarla (se recomienda 3 años, por la prescripción de
  las infracciones de la LOPDGDD).

---

## Medidas de seguridad (art. 32)

- Todo el tráfico va cifrado (HTTPS). Contraseñas guardadas con hash por Supabase Auth; mínimo de 8
  caracteres. La comprobación de contraseñas filtradas no está disponible en el plan gratuito de
  Supabase: **riesgo aceptado**, a revisar si se pasa a un plan de pago.
- Acceso a los datos solo a través de funciones de la base de datos que comprueban permisos y
  privacidad (políticas RLS); ninguna tabla se puede escribir directamente desde la API. La clave
  `service_role` nunca está en la web.
- Archivos privados con enlaces firmados de una hora; cada archivo, en la carpeta de su dueño.
- Límites de acciones por minuto; Content-Security-Policy estricta; sin scripts de terceros.
- Fechas de nacimiento no guardadas; coordenadas del pueblo descartadas; visitas como hash con sal.
- Pruebas automáticas de seguridad (más de 300 comprobaciones) antes de cada cambio.
- Copias de seguridad: las del plan de Supabase.
- Acceso de moderación limitado al contenido reportado.
