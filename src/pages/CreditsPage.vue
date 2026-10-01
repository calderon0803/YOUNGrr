<script setup>
import LegalDocument from '@/components/legal/LegalDocument.vue'

// Credits: the data and code of others that YOUNGrr uses, with the attribution
// their terms ask for.
</script>

<template>
  <LegalDocument title="Créditos">
    <h2>Datos</h2>
    <ul>
      <li class="credits__tmdb">
        <a class="credits__logo" href="https://www.themoviedb.org" rel="noopener" target="_blank">
          <img src="/credits/tmdb-logo.svg" alt="The Movie Database (TMDB)" width="137" height="18" />
        </a>
        <strong>Películas y series:</strong> datos y carátulas de
        <a href="https://www.themoviedb.org" rel="noopener" target="_blank">TMDB (The Movie Database)</a>. Este producto
        usa la API de TMDB, pero TMDB no lo avala ni lo certifica.
      </li>
      <li>
        <strong>Artistas:</strong> datos de <a href="https://musicbrainz.org" rel="noopener" target="_blank">MusicBrainz</a>
        (MetaBrainz Foundation), bajo licencia CC0.
      </li>
      <li>
        <strong>Ciudades y pueblos:</strong> búsqueda de
        <a href="https://nominatim.openstreetmap.org" rel="noopener" target="_blank">Nominatim</a> con datos ©
        <a href="https://www.openstreetmap.org/copyright" rel="noopener" target="_blank">colaboradores de OpenStreetMap</a>,
        bajo licencia ODbL.
      </li>
    </ul>

    <h2>Programas</h2>
    <ul>
      <li>Iconos: <a href="https://lucide.dev" rel="noopener" target="_blank">Lucide</a> (licencia ISC).</li>
      <li>
        Revisión de imágenes en tu dispositivo: <a href="https://github.com/infinitered/nsfwjs" rel="noopener" target="_blank">NSFWJS</a>
        (licencia MIT), sobre TensorFlow.js (licencia Apache 2.0).
      </li>
      <li>Hecho con <a href="https://vuejs.org" rel="noopener" target="_blank">Vue</a>, Pinia y Vite (licencia MIT).</li>
      <li>Servidor y base de datos: <a href="https://supabase.com" rel="noopener" target="_blank">Supabase</a>. Web alojada en Netlify.</li>
    </ul>
  </LegalDocument>
</template>

<style lang="scss" scoped>
// TMDB asks for its logo, never more prominent than YOUNGrr's.
.credits__logo {
  display: block;
  width: fit-content;
  margin-bottom: $space-1;

  img {
    display: block;
    width: auto;
    height: 1rem;
  }
}
</style>
