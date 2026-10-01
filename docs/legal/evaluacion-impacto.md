# Evaluación de impacto: ¿hace falta?

Artículo 35 del RGPD y lista de tratamientos que requieren evaluación de impacto de la AEPD.
Versión del 1 de octubre de 2026. **Borrador para revisar.**

## Criterios

La AEPD pide una evaluación de impacto (EIPD) cuando se cumplen **dos o más** de sus criterios. Para
YOUNGrr:

| Criterio de la AEPD | ¿Se cumple? | Por qué |
|---|---|---|
| Perfilado o evaluación de personas | No | No hay recomendaciones por comportamiento ni publicidad. Los logros salen de contadores simples. |
| Decisiones automatizadas con efectos jurídicos | No | El único filtro automático (imágenes) se ejecuta en el dispositivo y solo impide subir; retirar contenido lo decide una persona. |
| Observación sistemática | No | No se sigue la actividad de nadie para analizarla. |
| Categorías especiales de datos | No buscado | La app no las pide, aunque la gente pueda publicarlas. |
| Datos a gran escala | Hoy no | Comunidad pequeña por invitación. **Revisar al superar unos miles de cuentas.** |
| Asociación de conjuntos de datos | No | |
| Personas vulnerables | Limitado | Solo mayores de 18. Pueden aparecer menores en fotos que suben otros. |
| Uso innovador de tecnologías | Bajo | Clasificador de imágenes en el propio dispositivo. |
| Datos de localización | Parcial | Solo el nombre del pueblo (sin coordenadas) y la pertenencia a grupos de lugares. |
| Impide ejercer un derecho o usar un servicio | No | |

**Conclusión provisional:** se cumple como mucho un criterio de forma clara, así que **no es
obligatoria** una EIPD ahora. Conviene repetir este análisis al crecer o al añadir funciones de
ubicación, recomendaciones o publicidad.

## Riesgos identificados y medidas

| Riesgo | Medidas |
|---|---|
| Revelar dónde vive alguien (grupos de lugares) | Aviso al unirse; opción de solo contar en el total; sin coordenadas. |
| Fotos de terceros sin su consentimiento | Normas, etiquetas solo de amigos, aviso de contenido ilegal con un solo reporte, retirada rápida. |
| Acoso o contenido ilegal | Bloqueos, reportes, avisos de contenido ilegal (DSA, art. 16), moderación con motivación y apelación. |
| Acceso indebido a cuentas | Contraseñas con hash, mínimo de 8 caracteres, límites de intentos de Supabase. Sin comprobación de contraseñas filtradas (plan gratuito): riesgo aceptado. |
| Acceso indebido a datos | Funciones con permisos, RLS, sin escrituras directas, pruebas de seguridad automáticas. |
| Envío de datos a terceros países | Solo IP y texto buscado en los catálogos; informado en la política de privacidad. |
| Moderador con demasiado acceso | Solo ve el contenido reportado y la explicación de las apelaciones. |
