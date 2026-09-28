<script setup>
import AppLogo from '@/components/common/AppLogo.vue'
import GrrIcon from '@/components/common/GrrIcon.vue'
import LoginForm from '@/components/auth/LoginForm.vue'
import DemoAccounts from '@/components/auth/DemoAccounts.vue'

// DATA
const MOSAIC = [
  { seed: 'verano-3', caption: 'Atardecer desde el faro' },
  { seed: 'cumple-5', caption: 'Cumpleaños de Ana' },
  { seed: 'lisboa-2', caption: 'Alfama' },
  { seed: 'fiestas-1', caption: 'Semana Grande' },
  { seed: 'futbol-3', caption: 'Liga de los domingos' },
  { seed: 'viajes-5', caption: 'Oporto' },
].map((p) => ({ ...p, url: `https://picsum.photos/seed/yg-${p.seed}/480/480` }))
</script>

<template>
  <div class="landing">
    <section class="landing__intro" aria-labelledby="landing-title">
      <h1 id="landing-title" class="landing__title">
        Mira qué están haciendo <span class="landing__accent">tus amigos</span>.
      </h1>
      <p class="landing__lead">
        <AppLogo size="sm" /> es una red social de amigos, no de seguidores. Publicaciones, fotos, planes y conversaciones
        con la gente que conoces.
      </p>

      <ul class="landing__mosaic" role="list" aria-label="Fotos de ejemplo">
        <li v-for="(photo, i) in MOSAIC" :key="photo.seed" class="landing__tile" :class="`landing__tile--${i + 1}`">
          <img :src="photo.url" alt="" loading="lazy" />
          <span class="landing__tile-caption">{{ photo.caption }}</span>
        </li>
      </ul>

      <ul class="landing__points" role="list">
        <li><strong>Tu inicio es de tus amigos.</strong> Nada de desconocidos, tendencias ni contenido viral.</li>
        <li><strong>Las fotos mandan.</strong> Álbumes, etiquetas y comentarios, como siempre debió ser.</li>
        <li><strong>Planes de verdad.</strong> Crea eventos, invita y mira quién se apunta.</li>
        <li class="landing__grr">
          <GrrIcon class="landing__grr-icon" active />
          <span><strong>Grr</strong> es cómo dices que algo te gusta. Con un poco más de actitud.</span>
        </li>
      </ul>
    </section>

    <section class="landing__access panel" aria-labelledby="access-title">
      <h2 id="access-title" class="landing__access-title">Entra en YOUNGrr</h2>
      <LoginForm />
      <p class="landing__register">
        ¿Todavía no tienes cuenta?
        <RouterLink :to="{ name: 'register' }">Créala en un minuto</RouterLink>
      </p>
      <DemoAccounts class="landing__demo" />
    </section>
  </div>
</template>

<style lang="scss" scoped>
.landing {
  display: grid;
  gap: $space-6;

  &__title {
    font-size: $fs-xxl;
    font-weight: 800;
    letter-spacing: -0.03em;
    line-height: 1.05;
  }

  &__accent {
    color: $color-link;
  }

  &__lead {
    max-width: 34rem;
    margin-top: $space-3;
    font-size: $fs-md;
    color: $color-text-muted;

    .logo {
      vertical-align: -0.1em;
    }
  }

  &__mosaic {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: $space-2;
    margin: $space-5 0;
  }

  &__tile {
    position: relative;
    overflow: hidden;
    aspect-ratio: 1;
    background: $color-skeleton;
    border: 3px solid $color-surface;
    border-radius: $radius-sm;
    box-shadow: 0 1px 3px $color-shadow;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }

    &--2 {
      transform: rotate(1.5deg);
    }

    &--4 {
      transform: rotate(-1.5deg);
    }

    &--4,
    &--5,
    &--6 {
      display: none;
    }
  }

  &__tile-caption {
    display: none;
  }

  &__points {
    display: grid;
    gap: $space-3;
    margin: 0;

    li {
      padding-left: $space-3;
      border-left: 3px solid $color-brand-soft;
    }

    .landing__grr {
      display: flex;
      gap: $space-2;
      align-items: flex-start;
      border-left-color: $color-grr;
    }
  }

  &__grr-icon {
    flex-shrink: 0;
    color: $color-grr;
  }

  &__access {
    display: flex;
    flex-direction: column;
    gap: $space-4;
    padding: $space-5;
  }

  &__access-title {
    font-size: $fs-lg;
    font-weight: 800;
  }

  &__register {
    color: $color-text-muted;
  }

  &__demo {
    padding-top: $space-4;
    border-top: 1px solid $color-border;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .landing {
    &__title {
      font-size: 2.75rem;
    }

    &__tile {
      &--4,
      &--5,
      &--6 {
        display: block;
      }
    }

    &__tile-caption {
      position: absolute;
      right: 0;
      bottom: 0;
      left: 0;
      display: block;
      padding: $space-4 $space-2 $space-1;
      background: linear-gradient(transparent, $color-overlay);
      color: $color-on-brand;
      font-size: $fs-xs;
      font-weight: 600;
    }
  }
}

@media (min-width: $bp-desktop) {
  .landing {
    grid-template-columns: minmax(0, 1fr) 24rem;
    align-items: start;
    gap: $space-10;

    &__title {
      font-size: 3.25rem;
    }

    &__access {
      position: sticky;
      top: $space-6;
    }
  }
}
</style>
