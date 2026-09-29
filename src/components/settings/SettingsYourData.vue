<script setup>
import { computed, reactive, ref } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/services/errors'
import { useToast } from '@/composables/useToast'
import { toDateInput } from '@/utils/time'

// "Descargar mis datos" (JSON with everything YOUNGrr holds about you) and
// "Eliminar mi cuenta" (irreversible: data, files and session).

// STORES
const auth = useAuthStore()
const toast = useToast()

// DATA
const CONFIRM_WORD = 'ELIMINAR'
const exporting = ref(false)
const deleting = ref(false)
const open = ref(false)
const form = reactive({ word: '', password: '' })
const error = ref('')

// COMPUTED
const canDelete = computed(() => form.word.trim().toUpperCase() === CONFIRM_WORD && (auth.isLocalBackend || !!form.password))

// METHODS
const download = async () => {
  exporting.value = true
  try {
    const data = await auth.exportData()
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `youngrr-mis-datos-${toDateInput(new Date())}.json`
    link.click()
    URL.revokeObjectURL(url)
  } catch (e) {
    toast.error(errorMessage(e))
  } finally {
    exporting.value = false
  }
}

const openDelete = () => {
  Object.assign(form, { word: '', password: '' })
  error.value = ''
  open.value = true
}

const remove = async () => {
  if (!canDelete.value) return
  deleting.value = true
  error.value = ''
  try {
    await auth.deleteAccount(form.password)
  } catch (e) {
    error.value = errorMessage(e)
    deleting.value = false
  }
}
</script>

<template>
  <div class="your-data">
    <div class="your-data__row">
      <div>
        <p><strong>Descargar mis datos</strong></p>
        <p class="muted">
          Un archivo JSON con tu perfil, ajustes, estado, fotos (con enlaces de descarga que caducan en una hora), comentarios, Grr,
          amistades, eventos, mensajes enviados, invitaciones y reportes. No incluye contenido de otras personas.
        </p>
      </div>
      <button type="button" class="btn btn--secondary" :disabled="exporting" @click="download">
        {{ exporting ? 'Preparando…' : 'Descargar mis datos' }}
      </button>
    </div>

    <div class="your-data__row">
      <div>
        <p><strong>Eliminar mi cuenta</strong></p>
        <p class="muted">Se borran tu cuenta, tu perfil, tus fotos y todo lo que has publicado. No se puede deshacer.</p>
      </div>
      <button type="button" class="btn btn--danger" @click="openDelete">Eliminar mi cuenta</button>
    </div>

    <BaseModal :open="open" title="Eliminar mi cuenta" size="sm" :busy="deleting" @close="open = false">
      <form class="form-grid" novalidate @submit.prevent="remove">
        <p><strong>Esta acción es irreversible.</strong> Se eliminarán:</p>
        <ul class="your-data__list">
          <li>tu cuenta, tu perfil y tus ajustes;</li>
          <li>tus fotos y álbumes (también los archivos), tu estado, comentarios y Grr;</li>
          <li>tus amistades, eventos creados y mensajes del tablón;</li>
          <li>tus conversaciones privadas, para las dos personas.</li>
        </ul>
        <p class="muted">Los reportes que hayas enviado se conservan para la moderación, sin tu nombre.</p>
        <div v-if="!auth.isLocalBackend" class="field">
          <label class="field__label" for="delete-password">Tu contraseña</label>
          <input id="delete-password" v-model="form.password" class="input" type="password" autocomplete="current-password" />
        </div>
        <div class="field">
          <label class="field__label" for="delete-word">Escribe {{ CONFIRM_WORD }} para confirmar</label>
          <input id="delete-word" v-model="form.word" class="input" autocomplete="off" />
        </div>
        <p v-if="error" class="field__error" role="alert">{{ error }}</p>
        <div class="your-data__actions">
          <button type="button" class="btn btn--ghost" :disabled="deleting" @click="open = false">Cancelar</button>
          <button type="submit" class="btn btn--danger" :disabled="!canDelete || deleting">
            {{ deleting ? 'Eliminando…' : 'Eliminar para siempre' }}
          </button>
        </div>
      </form>
    </BaseModal>
  </div>
</template>

<style lang="scss" scoped>
.your-data {
  display: flex;
  flex-direction: column;
  gap: $space-4;

  &__row {
    display: flex;
    flex-direction: column;
    gap: $space-2;
    align-items: flex-start;
  }

  &__list {
    margin: 0;
    padding-left: $space-5;
    list-style: disc;
  }

  &__actions {
    display: flex;
    justify-content: flex-end;
    gap: $space-2;
  }
}
</style>
