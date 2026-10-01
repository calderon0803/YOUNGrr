# Encargados del tratamiento y transferencias internacionales

Artículos 28 y 44 a 49 del RGPD. Versión del 1 de octubre de 2026. **Borrador para revisar.**

## Encargados (tratan datos por cuenta de YOUNGrr)

Con cada uno hay que tener aceptado su contrato de encargado del tratamiento (DPA) y guardar una
copia (PDF o captura con la fecha).

| Proveedor | Qué hace | Dónde | Contrato (DPA) | Estado |
|---|---|---|---|---|
| Supabase | Base de datos, cuentas, archivos, correos de la cuenta | UE: región `eu-west-1` (Irlanda), comprobado el 1 de octubre de 2026 | DPA de Supabase (versión 1, 1 de agosto de 2026): forma parte de sus condiciones de servicio y se aplica al aceptarlas, sin firma aparte. Está en supabase.com/legal/customer-resources/data-processing-addendum; no hay descarga: se guarda imprimiéndolo a PDF. Lista de subencargados: supabase.com/legal/customer-resources/subprocessor-list | Guardado en PDF (1/10/2026) |
| Netlify | Aloja la web | EE. UU. y red global | DPA de Netlify, en PDF en netlify.com/pdf/netlify-dpa.pdf (enlazado desde netlify.com/gdpr-ccpa) | Guardado en PDF (1/10/2026) |

## Transferencias fuera del Espacio Económico Europeo

| Destino | Qué datos | Garantía |
|---|---|---|
| Netlify (EE. UU.) | Datos de conexión al cargar la web (IP, navegador) | Marco de Privacidad de Datos UE-EE. UU.: Netlify, Inc. figura como **activo** (también en la extensión de Reino Unido y en el marco suizo) para datos que no son de recursos humanos, comprobado en dataprivacyframework.gov el 1 de octubre de 2026. Además, las cláusulas contractuales tipo de su DPA. |
| TMDB (EE. UU.) | IP y texto buscado, desde el navegador | No es encargado: el navegador hace la petición. Informado en la política de privacidad. |
| MusicBrainz / MetaBrainz (EE. UU.) | IP y texto buscado, desde el navegador | Igual que TMDB. |
| OpenStreetMap / Nominatim (Reino Unido) | IP y texto buscado, desde el navegador | Decisión de adecuación de la UE para el Reino Unido. |

## Condiciones de uso de los servicios de datos

- **TMDB:** uso no comercial con la clave actual; frase de atribución y enlace en la web (están en el
  diálogo de gustos y en Créditos) y su logo oficial en Créditos (`public/credits/tmdb-logo.svg`,
  descargado de su página de logos y atribución). Si hubiera ingresos, hace falta su licencia comercial.
- **MusicBrainz:** datos CC0; como mucho una petición por segundo (la app lo respeta).
- **Nominatim:** como mucho una petición por segundo, sin uso masivo, atribución a OpenStreetMap (está
  puesta). Si el uso crece, contratar un servicio de geocodificación o montar uno propio.
