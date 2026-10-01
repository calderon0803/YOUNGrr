# Antes de abrir YOUNGrr al público

Lo que ya está hecho en la app y lo que queda pendiente. Versión del 1 de octubre de 2026.

## Hecho en la app

- [x] Avisos de contenido ilegal con un solo aviso, también sin cuenta (`/legal/report`), con tipo,
      explicación y declaración de buena fe (DSA, art. 16).
- [x] Al retirar contenido, aviso al dueño con la norma incumplida, que lo decidió una persona y
      cómo recurrir: apelación, resolución extrajudicial y tribunales (DSA, arts. 17, 20 y 21).
- [x] Punto de contacto y aviso legal (`/legal/notice`) (DSA, arts. 11 y 12; LSSI, art. 10).
- [x] Créditos con la atribución y el logo de TMDB, MusicBrainz y OpenStreetMap (`/legal/credits`).
- [x] Grupos de lugares: aviso al unirse y opción de solo contar en el total.
- [x] Registro de tratamientos, análisis de evaluación de impacto y procedimiento de brechas (esta carpeta).

## Pendiente (tuyo)

- [ ] **NIF y domicilio** en `LEGAL.taxId` y `LEGAL.address` (`src/config/app.js`), o crear antes una
      asociación o sociedad y poner sus datos.
- [x] DPA de Supabase y Netlify y lista de subencargados de Supabase guardados en PDF (1 de octubre de 2026).
      Supabase en la UE (`eu-west-1`) y Netlify activo en el Marco de Privacidad UE-EE. UU. Revisarlos una vez
      al año o cuando avisen de cambios.
- [ ] **Marca:** registrar «YOUNGrr» en la OEPM o la EUIPO si vas en serio. No usar «Tuenti» en
      ningún sitio.
- [ ] **Revisión por un abogado** de las condiciones, la privacidad, el aviso legal y estos documentos.
- [ ] Si algún día hay ingresos (publicidad, cuotas): darte de alta como actividad económica,
      licencia comercial de TMDB y repasar de nuevo todo esto.
