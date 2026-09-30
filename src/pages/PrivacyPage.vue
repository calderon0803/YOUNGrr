<script setup>
import LegalDocument from '@/components/legal/LegalDocument.vue'
import { LEGAL } from '@/config/app'
import { LIMITS } from '@/utils/validation'

// Privacy policy (GDPR art. 13). The retention periods must match the
// retention_settings table and the export must match export_my_data().
</script>

<template>
  <LegalDocument title="Política de privacidad">
    <p>
      YOUNGrr es una red social gratuita, sin publicidad y solo por invitación. Aquí se explica qué datos tuyos se
      tratan, para qué, durante cuánto tiempo y qué puedes hacer con ellos.
    </p>

    <h2>Quién es el responsable</h2>
    <p>
      {{ LEGAL.controller }}, que gestiona YOUNGrr como proyecto personal y sin ánimo de lucro. Para cualquier cuestión
      sobre tus datos, escribe a <a :href="`mailto:${LEGAL.contactEmail}`">{{ LEGAL.contactEmail }}</a>.
    </p>

    <h2>Qué datos tratamos</h2>
    <ul>
      <li><strong>Cuenta:</strong> tu correo y tu contraseña (guardada cifrada; nadie puede leerla).</li>
      <li>
        <strong>Edad:</strong> al registrarte pedimos tu fecha de nacimiento solo para comprobar que tienes
        {{ LIMITS.minAge }} años o más. No la guardamos: solo guardamos que lo confirmaste.
      </li>
      <li>
        <strong>Perfil:</strong> nombre, apellido, foto de perfil y portada, y lo que quieras añadir: presentación,
        cumpleaños, estudios, trabajo y ciudad o pueblo.
      </li>
      <li>
        <strong>Ubicación (opcional):</strong> si eliges tu ciudad o pueblo, guardamos sus coordenadas aproximadas para
        «Cerca de ti». Nunca pedimos la ubicación de tu dispositivo, y a los demás no se les muestran tus coordenadas.
      </li>
      <li>
        <strong>Lo que publicas y haces:</strong> estados, fotos, álbumes, etiquetas, comentarios, Grr, mensajes del
        tablón, eventos, mensajes privados, amistades, solicitudes, bloqueos y el contador de visitas de tu perfil (solo
        el número, no quién te visita).
      </li>
      <li>
        <strong>Invitaciones:</strong> los enlaces que creas, quién entró con cada uno y cuándo. No guardamos datos de la
        persona invitada hasta que crea su cuenta.
      </li>
      <li>
        <strong>Logros:</strong> a partir de lo que ya haces en YOUNGrr (fotos, amigos, planes, Grr, tablón) calculamos
        los logros que consigues y cuándo. Se ven en tu perfil, para quien puede verlo, y solo aparecen en las Novedades de
        tus amigos si decides compartirlos.
      </li>
      <li>
        <strong>Visitas a perfiles:</strong> para que la misma persona no cuente más de una vez cada 6 horas, cada visita
        deja una marca cifrada con una clave secreta. No contiene tu nombre ni el del perfil, nadie puede consultarla y se
        borra a las 6 horas. Del perfil solo se guarda el total.
      </li>
      <li>
        <strong>Reportes:</strong> si reportas algo, guardamos quién lo reporta, el motivo y una copia del contenido para
        que se pueda revisar. Llega a moderación cuando lo reportan 10 personas distintas (un mensaje privado, con uno, o con dos en un chat de más de 5 personas), y
        quien modera ve cuántos reportes hay y sus motivos, no quién los hizo. La persona reportada no sabe quién la ha
        reportado. Si se retira algo tuyo, deja de verse
        pero guardamos una copia durante 14 días (o hasta que se resuelva tu apelación) para poder devolvértelo, y un
        aviso para ti con el motivo. Si apelas, guardamos también tu explicación.
      </li>
      <li>
        <strong>Datos técnicos:</strong> para que el servicio funcione y sea seguro, los proveedores registran datos de
        conexión (dirección IP, fecha, navegador). Contamos también cuántas acciones haces por minuto, para frenar el spam;
        ese recuento se borra en una hora.
      </li>
    </ul>

    <h2>Para qué y con qué base legal</h2>
    <ul>
      <li>
        <strong>Prestarte el servicio</strong> (tu cuenta, tu perfil, compartir con tus amigos, mensajes, eventos,
        «Cerca de ti» si lo activas): es necesario para cumplir las condiciones de uso que aceptas (art. 6.1.b RGPD).
      </li>
      <li>
        <strong>Seguridad y convivencia</strong> (comprobar la edad, límites de uso, bloqueos, revisar reportes, retirar
        contenido que incumple las normas y atender las apelaciones): interés legítimo en mantener una red segura
        (art. 6.1.f RGPD).
      </li>
    </ul>
    <p>
      Antes de subir una foto, la app comprueba en tu propio dispositivo que no parezca contener desnudos o contenido
      sexual. Esa comprobación no envía la foto a nadie ni guarda el resultado: si no la supera, simplemente no se sube.
    </p>
    <p>
      No vendemos tus datos, no mostramos publicidad, no hacemos perfiles comerciales y no tomamos decisiones
      automatizadas que te afecten de forma importante.
    </p>

    <h2>Quién puede ver tus datos</h2>
    <p>
      Cualquier persona con cuenta puede ver tu nombre y tu foto de perfil. El resto de tu perfil y de lo que publicas lo
      ve quien permitas en <em>Configuración &gt; Privacidad</em>. Los mensajes privados solo los ven las personas de la
      conversación; en un chat de grupo, sus miembros ven tu nombre y tus mensajes, y quien lo creó puede añadir o quitar
      personas. Quien modera solo accede al contenido que se ha reportado y, si apelas una retirada, a tu explicación.
    </p>
    <ul>
      <li>
        <strong>Sugerencias de amistad:</strong> puedes aparecer como sugerencia, con tu nombre, tu foto y cuántos amigos
        tenéis en común, a personas con las que compartes algún amigo. Si en <em>Configuración &gt; Privacidad</em> no
        admites solicitudes de amistad, no apareces.
      </li>
      <li>
        <strong>Eventos públicos:</strong> un evento público lo ven los amigos de quien lo organiza y los amigos de sus
        amigos, incluida la lista de quién va. Si te apuntas a uno, esas personas verán tu nombre y tu respuesta. Los
        eventos con invitación solo los ven quien los organiza y las personas invitadas.
      </li>
      <li>
        <strong>Logros:</strong> los ve quien puede ver tu perfil. En las Novedades de tus amigos solo aparecen los que tú
        decides compartir.
      </li>
      <li>
        <strong>Bloqueos:</strong> si bloqueas a alguien, o te bloquea, dejáis de ver el contenido del otro, sus eventos
        públicos y sus sugerencias. No se avisa a la otra persona.
      </li>
    </ul>
    <p>Además, estos proveedores tratan datos por nuestra cuenta, solo para prestar el servicio:</p>
    <ul>
      <li><strong>Supabase</strong>: base de datos, cuentas, archivos y correos de la cuenta. Los datos se guardan en la Unión Europea.</li>
      <li>
        <strong>Netlify</strong>: aloja la web. Puede tratar datos de conexión en Estados Unidos, con las garantías del
        Marco de Privacidad de Datos UE-EE. UU. y las cláusulas contractuales tipo de la Comisión Europea.
      </li>
      <li>
        <strong>OpenStreetMap (Nominatim)</strong>: cuando buscas tu ciudad o pueblo, recibe el texto que escribes y tu
        dirección IP. Está en el Reino Unido, que cuenta con una decisión de adecuación de la Unión Europea.
      </li>
    </ul>

    <h2>Cuánto tiempo los guardamos</h2>
    <p>Mientras tengas cuenta, salvo estos datos, que se borran antes:</p>
    <table>
      <thead>
        <tr><th scope="col">Dato</th><th scope="col">Se borra</th></tr>
      </thead>
      <tbody>
        <tr><td>Enlaces de invitación sin usar</td><td>Al caducar (30 días)</td></tr>
        <tr><td>Avisos ya vistos</td><td>A los 90 días</td></tr>
        <tr><td>Avisos no vistos</td><td>Al año</td></tr>
        <tr><td>Solicitudes de amistad rechazadas o canceladas</td><td>A los 30 días</td></tr>
        <tr><td>Invitaciones para compartir una foto rechazadas</td><td>A los 30 días</td></tr>
        <tr><td>Reportes ya revisados, con su copia del contenido</td><td>Al año de la decisión</td></tr>
        <tr><td>Reportes que no llegan al mínimo para revisarse</td><td>A los 90 días</td></tr>
        <tr><td>Recuento de acciones por minuto</td><td>En una hora</td></tr>
        <tr><td>Marca de visita a un perfil</td><td>A las 6 horas</td></tr>
        <tr><td>Copia de contenido retirado</td><td>A los 14 días, o al resolverse la apelación</td></tr>
        <tr><td>Aviso de contenido retirado y apelación</td><td>Al cerrarlo, una vez resuelto</td></tr>
      </tbody>
    </table>
    <p>
      Si eliminas tu cuenta, se borran en ese momento tu perfil, tus archivos y todo lo que has publicado, incluidas tus
      conversaciones de dos personas (también para la otra persona) y tus mensajes en los chats de grupo, que siguen
      para los demás. Solo se conservan, sin tu nombre, los
      reportes que hiciste, hasta que venza su plazo. Los registros técnicos de los proveedores se borran según sus
      propios ciclos.
    </p>

    <h2>Tus derechos</h2>
    <p>Puedes ejercerlos desde la propia app o escribiendo a <a :href="`mailto:${LEGAL.contactEmail}`">{{ LEGAL.contactEmail }}</a>:</p>
    <ul>
      <li><strong>Acceso y portabilidad:</strong> <em>Configuración &gt; Cuenta &gt; Descargar mis datos</em> te da un archivo con tu cuenta, tu perfil, lo que has publicado, tus amistades, tus logros y tus conversaciones completas, más enlaces temporales a tus fotos.</li>
      <li><strong>Rectificación:</strong> puedes editar tu perfil y tu contenido en cualquier momento.</li>
      <li><strong>Supresión:</strong> <em>Configuración &gt; Cuenta &gt; Eliminar mi cuenta</em>.</li>
      <li><strong>Oposición y limitación:</strong> por correo, explicando tu caso.</li>
    </ul>
    <p>
      Responderemos en un plazo máximo de un mes. Si no estás de acuerdo con la respuesta, puedes reclamar ante la
      Agencia Española de Protección de Datos (<a href="https://www.aepd.es" rel="noopener" target="_blank">aepd.es</a>).
    </p>

    <h2>Menores</h2>
    <p>YOUNGrr es solo para mayores de {{ LIMITS.minAge }} años. Si detectamos una cuenta de un menor, la eliminamos.</p>

    <h2>Cookies y almacenamiento del navegador</h2>
    <p>
      No usamos cookies de publicidad ni de analítica. El navegador guarda solo lo imprescindible para que la app
      funcione: tu sesión, tus preferencias (como el tema o los chats abiertos), los perfiles que has abierto en las
      últimas 6 horas (para no volver a enviar la visita) y los archivos de la app para que cargue rápido. Al cerrar sesión se borra lo relacionado con tu cuenta.
    </p>

    <h2>Cambios</h2>
    <p>
      Si cambia esta política, actualizaremos la fecha de arriba y te pediremos que la aceptes de nuevo la próxima vez que
      entres.
    </p>
  </LegalDocument>
</template>
