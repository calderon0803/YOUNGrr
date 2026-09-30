<script setup>
import { reactive, ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import CityPicker from '@/components/common/CityPicker.vue'
import { useUserStore } from '@/stores/user'
import { errorMessage } from '@/services/errors'
import { LIMITS } from '@/utils/validation'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  profile: { type: Object, required: true },
})

const emit = defineEmits(['close'])

// STORES
const user = useUserStore()

// DATA
const form = reactive({ firstName: '', lastName: '', location: null, bio: '', birthday: '', studies: '', work: '' })
const saving = ref(false)
const error = ref('')

// METHODS
const save = async () => {
  saving.value = true
  error.value = ''
  try {
    await user.updateProfile({ ...form, birthday: form.birthday || null })
    emit('close')
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    saving.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    const p = props.profile
    Object.assign(form, { firstName: p.firstName, lastName: p.lastName, location: p.city ? { name: p.city } : null, bio: p.bio, birthday: p.birthday ?? '', studies: p.studies, work: p.work })
    error.value = ''
  },
  { immediate: true },
)
</script>

<template>
  <BaseModal :open="open" title="Editar perfil" :busy="saving" @close="emit('close')">
    <form id="profile-form" class="form-grid profile-form" novalidate @submit.prevent="save">
      <div class="profile-form__row">
        <div class="field">
          <label class="field__label" for="pf-first">Nombre</label>
          <input id="pf-first" v-model="form.firstName" class="input" :maxlength="LIMITS.name" required autofocus />
        </div>
        <div class="field">
          <label class="field__label" for="pf-last">Apellido</label>
          <input id="pf-last" v-model="form.lastName" class="input" :maxlength="LIMITS.name" required />
        </div>
      </div>
      <div class="field">
        <label class="field__label" for="pf-bio">Biografía</label>
        <textarea id="pf-bio" v-model="form.bio" class="textarea" rows="3" :maxlength="LIMITS.bio" />
        <p class="field__hint">{{ LIMITS.bio - form.bio.length }} caracteres disponibles</p>
      </div>
      <div class="profile-form__row">
        <CityPicker v-model="form.location" label="Ciudad o pueblo (opcional)" hint="Te sugeriremos los grupos de tu zona. Bórrala para quitarla." />
        <div class="field">
          <label class="field__label" for="pf-birthday">Cumpleaños (opcional)</label>
          <input id="pf-birthday" v-model="form.birthday" class="input" type="date" aria-describedby="pf-birthday-hint" />
          <p id="pf-birthday-hint" class="field__hint">Los demás solo ven el día y el mes, nunca el año.</p>
        </div>
      </div>
      <div class="field">
        <label class="field__label" for="pf-studies">Estudios</label>
        <input id="pf-studies" v-model="form.studies" class="input" :maxlength="LIMITS.about" />
      </div>
      <div class="field">
        <label class="field__label" for="pf-work">Trabajo</label>
        <input id="pf-work" v-model="form.work" class="input" :maxlength="LIMITS.about" />
      </div>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="saving" @click="emit('close')">Cancelar</button>
      <button type="submit" form="profile-form" class="btn btn--primary" :disabled="saving">{{ saving ? 'Guardando…' : 'Guardar' }}</button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.profile-form__row {
  display: grid;
  gap: $space-4;
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .profile-form__row {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
