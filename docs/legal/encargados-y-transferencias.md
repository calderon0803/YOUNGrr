# Encargados del tratamiento y transferencias internacionales

Artículos 28 y 44 a 49 del RGPD. Versión del 1 de octubre de 2026. **Borrador para revisar.**

## Encargados (tratan datos por cuenta de YOUNGrr)

Con cada uno hay que tener aceptado su contrato de encargado del tratamiento (DPA) y guardar una
copia (PDF o captura con la fecha).

| Proveedor | Qué hace | Dónde | Contrato (DPA) | Estado |
|---|---|---|---|---|
| Supabase | Base de datos, cuentas, archivos, correos de la cuenta | UE (región del proyecto) | DPA de Supabase: se acepta y descarga desde el panel de la organización (*Legal Documents*) | **Pendiente: aceptar y guardar** |
| Netlify | Aloja la web | EE. UU. y red global | DPA de Netlify (anexo a sus condiciones) | **Pendiente: aceptar y guardar** |

## Transferencias fuera del Espacio Económico Europeo

| Destino | Qué datos | Garantía |
|---|---|---|
| Netlify (EE. UU.) | Datos de conexión al cargar la web (IP, navegador) | Marco de Privacidad de Datos UE-EE. UU. (si Netlify está certificado) y cláusulas contractuales tipo. **Comprobar su certificación en dataprivacyframework.gov.** |
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
