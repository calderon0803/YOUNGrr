<script setup>
import { computed } from 'vue'
import LegalDocument from '@/components/legal/LegalDocument.vue'
import { ILLEGAL_CATEGORIES, LEGAL } from '@/config/app'

// Reporting illegal content without an account (Digital Services Act, art. 16):
// what to include, and an email already prepared. With an account it is done
// from "Reportar" > "Es ilegal" on the content itself.

// COMPUTED
const mailto = computed(() => {
  const body = [
    'Enlace al contenido (cópialo de la barra de direcciones):',
    '',
    'Por qué es ilegal (qué ocurre y, si lo sabes, qué ley incumple):',
    '',
    'Tu nombre y apellidos:',
    '',
    'Declaro de buena fe que la información de este aviso es exacta y completa.',
  ].join('\n')
  return `mailto:${LEGAL.contactEmail}?subject=${encodeURIComponent('Aviso de contenido ilegal en YOUNGrr')}&body=${encodeURIComponent(body)}`
})
</script>

<template>
  <LegalDocument title="Avisar de contenido ilegal">
    <p>
      Si has visto en YOUNGrr algo que crees que es ilegal, avísanos. Lo revisará una persona aunque solo nos lo digas
      tú, y te responderemos.
    </p>

    <h2>Si tienes cuenta</h2>
    <p>
      Lo más rápido es avisar desde el propio contenido: en su menú, <em>Reportar</em> y <em>Es ilegal</em>. Nadie sabrá
      que has sido tú.
    </p>

    <h2>Si no tienes cuenta</h2>
    <p>Escríbenos a <a :href="`mailto:${LEGAL.contactEmail}`">{{ LEGAL.contactEmail }}</a> con:</p>
    <ul>
      <li>el enlace exacto al contenido;</li>
      <li>por qué crees que es ilegal y, si lo sabes, qué ley incumple;</li>
      <li>tu nombre y un correo para responderte (salvo si se trata de abuso de menores, que puedes avisar sin identificarte);</li>
      <li>una declaración de que lo que cuentas es cierto según tu leal saber y entender.</li>
    </ul>
    <p><a class="btn btn--primary" :href="mailto">Escribir el aviso</a></p>

    <h2>Qué tipo de contenido</h2>
    <ul>
      <li v-for="category in ILLEGAL_CATEGORIES" :key="category.key">{{ category.label }}</li>
    </ul>
    <p>
      Si hay un peligro inmediato para la vida o la seguridad de alguien, llama al 112. Si se trata de abuso sexual de
      menores, puedes avisar también a la Policía Nacional o a la Guardia Civil.
    </p>

    <h2>Qué pasa después</h2>
    <p>
      Lo revisamos lo antes posible. Si es ilegal o incumple las condiciones, lo retiramos y avisamos a quien lo publicó,
      que puede apelar. Te diremos qué hemos decidido. Usamos tus datos solo para tramitar el aviso (ver la
      <RouterLink :to="{ name: 'privacy' }">política de privacidad</RouterLink>).
    </p>
  </LegalDocument>
</template>
