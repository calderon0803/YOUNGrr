# Procedimiento ante brechas de seguridad

Artículos 33 y 34 del RGPD. Versión del 1 de octubre de 2026. **Borrador para revisar.**

Una brecha es cualquier incidente que destruya, pierda, altere, comunique o dé acceso a datos
personales sin autorización: una clave expuesta, un fallo de permisos que deja ver datos ajenos, una
cuenta de administración comprometida, un proveedor que avisa de un incidente…

## 1. Contener (en cuanto se detecta)

- Cortar el acceso: rotar claves (Supabase, Netlify), cerrar sesiones, desactivar la función afectada.
- Si la causa es el código, desplegar el arreglo o revertir el último cambio.
- No borrar pruebas: guardar registros y capturas.

## 2. Evaluar (primeras horas)

Apuntar en el registro de brechas (abajo):
- qué ha pasado y cuándo (y cuándo se detectó);
- qué datos y cuántas personas están afectados, aproximadamente;
- consecuencias posibles (suplantación, exposición de mensajes, fotos…);
- si los datos estaban protegidos (por ejemplo, contraseñas con hash).

## 3. Notificar a la AEPD (máximo 72 horas desde que se conoce)

Salvo que sea **improbable** que suponga un riesgo para las personas. Se hace en la sede electrónica
de la AEPD (formulario de notificación de brechas). Si no se tiene toda la información, se notifica lo
que se sepa y se completa después.

## 4. Avisar a las personas afectadas (sin dilación)

Si es probable un **alto riesgo** para ellas (por ejemplo, se han expuesto mensajes privados o fotos
privadas). En lenguaje claro: qué ha pasado, qué datos, qué hemos hecho y qué pueden hacer (cambiar la
contraseña…). Por correo y con un aviso en la app.

## 5. Cerrar

Documentar la causa, el arreglo y cómo se evita que se repita.

## Registro de brechas

Hay que apuntar **todas**, se notifiquen o no (art. 33.5).

| Fecha | Qué pasó | Datos y personas | ¿Notificada a la AEPD? | ¿Aviso a afectados? | Medidas |
|---|---|---|---|---|---|
| — | — | — | — | — | — |
