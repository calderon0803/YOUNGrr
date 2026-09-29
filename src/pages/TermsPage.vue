<script setup>
import LegalDocument from '@/components/legal/LegalDocument.vue'
import { LEGAL } from '@/config/app'
import { LIMITS } from '@/utils/validation'

// Terms of use: who can join, the rules, moderation and what happens to the
// service. Accepted at sign up (and again when LEGAL.version changes).
</script>

<template>
  <LegalDocument title="Condiciones de uso">
    <p>
      YOUNGrr es una red social para compartir con tus amigos. La gestiona {{ LEGAL.controller }} como proyecto personal,
      gratuito, sin ánimo de lucro y sin publicidad. Al crear tu cuenta aceptas estas condiciones y la
      <RouterLink :to="{ name: 'privacy' }">política de privacidad</RouterLink>.
    </p>

    <h2>Quién puede usar YOUNGrr</h2>
    <ul>
      <li>Solo personas de {{ LIMITS.minAge }} años o más.</li>
      <li>Solo con invitación de alguien que ya tenga cuenta.</li>
      <li>Una cuenta por persona, con tu nombre real y datos veraces. No puedes hacerte pasar por otra persona.</li>
      <li>Tu contraseña es personal: no la compartas. Si crees que alguien ha entrado en tu cuenta, cámbiala y avísanos.</li>
    </ul>

    <h2>Tu contenido</h2>
    <p>
      Lo que publicas sigue siendo tuyo. Nos das permiso para guardarlo y mostrarlo solo a quien tú permites según tu
      configuración de privacidad, y solo mientras no lo borres. Ese permiso termina cuando lo eliminas o eliminas tu
      cuenta.
    </p>
    <p>
      Publica solo lo que tengas derecho a publicar. Si subes fotos en las que aparecen otras personas o las etiquetas,
      asegúrate de que están de acuerdo. Si alguien te pide que quites una foto suya, quítala.
    </p>

    <h2>Normas de convivencia</h2>
    <p>No está permitido:</p>
    <ul>
      <li>Acosar, amenazar, intimidar o humillar a nadie.</li>
      <li>Publicar contenido que incite al odio o a la violencia, o que discrimine a nadie.</li>
      <li>Publicar contenido sexual explícito, y en ningún caso contenido sexual de otras personas sin su consentimiento.</li>
      <li>Publicar cualquier contenido que implique a menores de forma inapropiada.</li>
      <li>Difundir datos personales de otras personas (dirección, teléfono, documentos…) sin su permiso.</li>
      <li>Enviar spam, cadenas o publicidad, o usar programas para automatizar acciones o extraer datos.</li>
      <li>Publicar contenido ilegal o que infrinja derechos de otros (como derechos de autor).</li>
      <li>Intentar saltarse las medidas de seguridad o acceder a cuentas o datos ajenos.</li>
    </ul>

    <h2>Moderación</h2>
    <p>
      Puedes reportar contenido y perfiles, y bloquear a cualquier persona. Quien modera revisa los reportes y puede
      retirar el contenido que incumpla estas normas. Si los incumplimientos son graves o se repiten, podemos suspender o
      eliminar la cuenta. Si no estás de acuerdo con una decisión, escribe a
      <a :href="`mailto:${LEGAL.contactEmail}`">{{ LEGAL.contactEmail }}</a> y la revisaremos.
    </p>
    <p>
      Si vemos contenido que pueda ser delito, podemos conservarlo y comunicarlo a las autoridades cuando la ley lo exija.
    </p>

    <h2>El servicio</h2>
    <ul>
      <li>
        YOUNGrr se ofrece tal cual, sin garantía de que esté siempre disponible o sin errores. Haremos lo posible por
        mantenerlo en marcha y proteger tus datos.
      </li>
      <li>
        Podemos cambiar o dejar de ofrecer funciones. Si YOUNGrr va a cerrar, avisaremos con al menos 30 días de antelación
        para que puedas descargar tus datos.
      </li>
      <li>
        Cada persona es responsable de lo que publica. Salvo en lo que la ley no permita limitar, no respondemos del
        contenido que publican los usuarios ni de los daños indirectos por usar o no poder usar el servicio.
      </li>
    </ul>

    <h2>Darte de baja</h2>
    <p>
      Puedes eliminar tu cuenta cuando quieras en <em>Configuración &gt; Cuenta</em>. Antes puedes descargar tus datos.
    </p>

    <h2>Cambios en estas condiciones</h2>
    <p>
      Si las cambiamos, actualizaremos la fecha de arriba y te pediremos que las aceptes de nuevo la próxima vez que entres.
      Si no las aceptas, puedes descargar tus datos y eliminar tu cuenta.
    </p>

    <h2>Ley aplicable y contacto</h2>
    <p>
      Estas condiciones se rigen por la ley española. Si tienes cualquier duda, escribe a
      <a :href="`mailto:${LEGAL.contactEmail}`">{{ LEGAL.contactEmail }}</a>.
    </p>
  </LegalDocument>
</template>
