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
      <li>
        Solo con invitación de alguien que ya tenga cuenta. Cada enlace de invitación sirve para una sola cuenta y quien
        lo usa se hace amigo de quien lo creó: compártelo solo con la persona a la que quieres invitar.
      </li>
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
    <p>
      Un evento público lo ven los amigos de tus amigos, aunque no te conozcan, y también quién va. No pongas en él datos que
      no quieras que vea esa gente, como la dirección de tu casa.
    </p>
    <p>
      En un grupo, lo que publicas en su Gallinero lo ven todas sus personas, aunque no sean tus amigas. Quien crea un
      grupo es su propietario: nombra a quien lo administra, y quienes lo administran aceptan a quien pide entrar, quitan
      personas y pueden borrar lo publicado que no encaje en el grupo. Cada persona puede crear hasta 10 grupos, de hasta
      200 personas; un grupo al que no se une nadie en 7 días se elimina solo. Las normas de convivencia se aplican
      igual dentro de los grupos. Menciona a la gente con respeto: una mención le avisa.
    </p>
    <p>
      Los grupos de lugares (comunidades, provincias, pueblos y ciudades) son de YOUNGrr: cualquiera puede unirse y los
      administra la moderación, que puede nombrar a otras personas para ayudar. El grupo de un pueblo o ciudad se crea
      cuando lo han pedido suficientes personas, y quienes lo pidieron entran en él.
    </p>

    <h2 id="normas">Normas de convivencia</h2>
    <p>No está permitido (cuando retiramos algo, te decimos qué norma incumple por su número):</p>
    <ol class="terms__rules">
      <li>Acosar, amenazar, intimidar o humillar a nadie.</li>
      <li>Publicar contenido que incite al odio o a la violencia, o que discrimine a nadie.</li>
      <li>Publicar contenido sexual explícito, y en ningún caso contenido sexual de otras personas sin su consentimiento.</li>
      <li>Publicar cualquier contenido que implique a menores de forma inapropiada.</li>
      <li>Difundir datos personales de otras personas (dirección, teléfono, documentos…) sin su permiso.</li>
      <li>Enviar spam, cadenas o publicidad, o usar programas para automatizar acciones o extraer datos.</li>
      <li>Publicar contenido ilegal.</li>
      <li>Infringir derechos de otras personas, como su imagen, sus derechos de autor o sus marcas.</li>
      <li>Intentar saltarse las medidas de seguridad o acceder a cuentas o datos ajenos.</li>
    </ol>

    <h2>Moderación</h2>
    <p>
      Antes de subir una foto, la app la analiza automáticamente en tu propio dispositivo y no deja subir las que parecen
      contener desnudos o contenido sexual. Es un filtro automático y puede equivocarse en ambos sentidos. Es la única
      decisión automática: todo lo que se retira lo decide una persona.
    </p>
    <p>
      <strong>Contenido ilegal.</strong> Cualquier persona, tenga cuenta o no, puede avisarnos de contenido ilegal: con
      cuenta, desde <em>Reportar</em> y <em>Es ilegal</em>; sin ella, desde
      <RouterLink :to="{ name: 'illegal-report' }">Avisar de contenido ilegal</RouterLink>. Basta un aviso para que lo
      revisemos, sin esperar a más reportes. Hay que explicar por qué es ilegal y declarar de buena fe que lo que se cuenta
      es cierto. Si alguien envía avisos falsos de forma repetida, podemos dejar de atenderlos.
    </p>
    <p>
      Puedes reportar contenido y perfiles, y bloquear a cualquier persona. Reportar no oculta nada: el contenido llega a
      moderación cuando lo reportan 10 personas distintas (un mensaje privado, con un solo reporte, o con dos en un chat de grupo de más de 5 personas; en el Gallinero de un grupo, el 30% de sus personas, entre 3 y 10). Quien modera lo
      revisa y puede retirar el contenido que incumpla estas normas. Si retiramos algo tuyo, te avisamos en la app con lo
      que se retiró, el motivo del reporte (nunca quién lo hizo), la norma que incumple y que lo ha decidido una persona.
      Tienes 14 días para apelar desde ese aviso: mientras tanto el contenido deja de verse pero se guarda, y si tienes
      razón vuelve a su sitio. Si no apelas o se rechaza la apelación, se borra del todo. Si los incumplimientos son graves
      o se repiten, podemos suspender o eliminar la cuenta. Si no estás de acuerdo con una decisión sobre tu cuenta,
      escribe a <a :href="`mailto:${LEGAL.contactEmail}`">{{ LEGAL.contactEmail }}</a> y la revisaremos.
    </p>
    <p>
      Además de apelar, puedes acudir a un órgano de resolución extrajudicial de litigios certificado según el Reglamento
      de Servicios Digitales, o a los tribunales.
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
        La experiencia y los niveles son solo un reconocimiento: no dan ventajas ni tienen valor fuera de YOUNGrr.
        Lo publicado da experiencia si sigue publicado 7 días después, y lo que retira la moderación antes no da nada.
        La experiencia ganada no se pierde, salvo la que se consiga haciendo trampas, que podemos corregir.
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

<style lang="scss" scoped>
.terms__rules {
  display: flex;
  flex-direction: column;
  gap: $space-1;
  margin: 0;
  padding-left: $space-5;
  list-style: decimal;
}
</style>
