<script setup>
import { ref } from 'vue'
import { Check, Copy, Share2 } from 'lucide-vue-next'
import { useToast } from '@/composables/useToast'

// A personal invitation link, ready to copy or share (WhatsApp, email...).

// PROPS
const props = defineProps({
  link: { type: String, required: true },
})

// STORES
const toast = useToast()

// DATA
const copied = ref(false)
const canShare = typeof navigator !== 'undefined' && 'share' in navigator

// METHODS
const copy = async () => {
  try {
    await navigator.clipboard.writeText(props.link)
    copied.value = true
    setTimeout(() => (copied.value = false), 2000)
  } catch {
    toast.error('No se ha podido copiar. Selecciona el enlace y cópialo a mano.')
  }
}

const share = async () => {
  try {
    await navigator.share({ title: 'Te invito a YOUNGrr', text: 'Te invito a YOUNGrr. Crea tu cuenta con este enlace:', url: props.link })
  } catch {
    // Closed by the user.
  }
}
</script>

<template>
  <div class="link">
    <input class="input link__url" :value="link" readonly aria-label="Enlace de invitación" @focus="$event.target.select()" />
    <button type="button" class="btn btn--secondary btn--sm btn--icon" :aria-label="copied ? 'Copiado' : 'Copiar enlace'" @click="copy">
      <Check v-if="copied" aria-hidden="true" />
      <Copy v-else aria-hidden="true" />
    </button>
    <button v-if="canShare" type="button" class="btn btn--secondary btn--sm btn--icon" aria-label="Compartir enlace" @click="share">
      <Share2 aria-hidden="true" />
    </button>
  </div>
</template>

<style lang="scss" scoped>
.link {
  display: flex;
  gap: $space-1;

  &__url {
    flex: 1;
    min-width: 0;
    min-height: 2rem;
    font-size: $fs-xs;
    color: $color-text-muted;
  }
}
</style>
