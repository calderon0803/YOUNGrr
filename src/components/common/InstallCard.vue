<script setup>
import { Download, Share, SquarePlus } from 'lucide-vue-next'
import { useInstallPrompt } from '@/composables/useInstallPrompt'
import { useToast } from '@/composables/useToast'

// DATA
const { standalone, canPrompt, needsManualSteps, install } = useInstallPrompt()
const toast = useToast()

// METHODS
const onInstall = async () => {
  if (await install()) toast.success('YOUNGrr se ha instalado.')
}
</script>

<template>
  <div class="install">
    <p v-if="standalone" class="install__text">Estás usando YOUNGrr como aplicación instalada.</p>

    <template v-else-if="canPrompt">
      <p class="install__text">Instala YOUNGrr para abrirlo desde tu pantalla de inicio como una aplicación más.</p>
      <button type="button" class="btn btn--primary" @click="onInstall">
        <Download aria-hidden="true" />
        Instalar YOUNGrr
      </button>
    </template>

    <template v-else-if="needsManualSteps">
      <p class="install__text">En iPhone y iPad, YOUNGrr se instala desde Safari:</p>
      <ol class="install__steps">
        <li>
          Pulsa <strong>Compartir</strong>
          <Share class="install__inline-icon" aria-hidden="true" />
          en la barra de Safari.
        </li>
        <li>
          Elige <strong>Añadir a pantalla de inicio</strong>
          <SquarePlus class="install__inline-icon" aria-hidden="true" />.
        </li>
        <li>Confirma con <strong>Añadir</strong>.</li>
      </ol>
      <p class="install__hint">
        Instalado, Safari conserva los datos guardados de YOUNGrr; en una pestaña normal puede borrarlos si pasas unos
        días sin entrar. Las notificaciones las verás al abrir la aplicación.
      </p>
    </template>

    <p v-else class="install__text">
      Abre YOUNGrr en Chrome, Edge o Safari para instalarlo. Si ya lo has instalado, ábrelo desde tu pantalla de inicio.
    </p>
  </div>
</template>

<style lang="scss" scoped>
.install {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: $space-3;

  &__text {
    color: $color-text;
  }

  &__steps {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    padding-left: $space-5;
  }

  &__inline-icon {
    display: inline-block;
    width: 1rem;
    height: 1rem;
    vertical-align: -0.15em;
  }

  &__hint {
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}
</style>
