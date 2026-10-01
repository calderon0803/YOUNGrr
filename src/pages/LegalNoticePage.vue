<script setup>
import LegalDocument from '@/components/legal/LegalDocument.vue'
import { LEGAL } from '@/config/app'

// Legal notice (Spanish LSSI, art. 10): who provides YOUNGrr and how to reach
// them. The tax id and address are set in LEGAL before opening to the public.

// DATA
const PENDING = 'Pendiente de completar'
</script>

<template>
  <LegalDocument title="Aviso legal">
    <h2>Quién está detrás de YOUNGrr</h2>
    <table>
      <tbody>
        <tr><th scope="row">Responsable</th><td>{{ LEGAL.controller }}</td></tr>
        <tr><th scope="row">NIF</th><td>{{ LEGAL.taxId || PENDING }}</td></tr>
        <tr><th scope="row">Domicilio</th><td>{{ LEGAL.address || PENDING }}</td></tr>
        <tr>
          <th scope="row">Correo de contacto</th>
          <td><a :href="`mailto:${LEGAL.contactEmail}`">{{ LEGAL.contactEmail }}</a></td>
        </tr>
      </tbody>
    </table>
    <p>
      YOUNGrr es un proyecto personal, gratuito y sin publicidad. Ese correo es también el punto de contacto para
      autoridades y personas usuarias previsto en el Reglamento de Servicios Digitales (artículos 11 y 12); puedes
      escribir en español o en inglés.
    </p>

    <h2>Condiciones y privacidad</h2>
    <p>
      El uso de YOUNGrr se rige por las <RouterLink :to="{ name: 'terms' }">condiciones de uso</RouterLink> y la
      <RouterLink :to="{ name: 'privacy' }">política de privacidad</RouterLink>.
    </p>

    <h2>Contenido ilegal</h2>
    <p>
      Cualquier persona, tenga cuenta o no, puede avisar de contenido ilegal publicado en YOUNGrr desde
      <RouterLink :to="{ name: 'illegal-report' }">Avisar de contenido ilegal</RouterLink>.
    </p>

    <h2>Propiedad intelectual</h2>
    <p>
      El nombre, el diseño y el código de YOUNGrr son de su responsable. Lo que publica cada persona es suyo (ver las
      condiciones de uso). Los datos de terceros que usa YOUNGrr se indican en los
      <RouterLink :to="{ name: 'credits' }">créditos</RouterLink>.
    </p>
  </LegalDocument>
</template>
