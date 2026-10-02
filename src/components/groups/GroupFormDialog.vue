<script setup>
import { computed, reactive, ref, watch } from 'vue'
import { ImagePlus, X } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useGroupsStore } from '@/stores/groups'
import { errorMessage } from '@/services/errors'
import { useImagePicker } from '@/composables/useImagePicker'
import { ACCEPTED_IMAGE_TYPES } from '@/utils/image'
import { groupAvatar } from '@/utils/groups'
import { LIMITS, firstError, rules } from '@/utils/validation'
import { GROUPS, IMAGE } from '@/config/app'

// Creates a group or edits one (its administrators), with its image: the
// same automatic check as photos; place groups keep their flag.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  /** Group to edit; null to create. */
  group: { type: Object, default: null },
})

const emit = defineEmits(['close', 'saved'])

// STORES
const groups = useGroupsStore()

// DATA
const PRIVACY = [
  { value: false, label: 'Cerrado', hint: 'Cualquiera lo encuentra por su nombre y puede pedir entrar; quien lo administra acepta o rechaza.' },
  { value: true, label: 'Secreto', hint: 'Solo lo conocen sus personas y quienes invitéis. No aparece en las búsquedas.' },
]
const form = reactive({ name: '', description: '', secret: false })
// The picked image (data URL), '' to remove it, or null to leave it as it is.
const image = ref(null)
const fileInput = ref(null)
const { processing, read } = useImagePicker({ maxSide: IMAGE.avatarMaxSide })
const errors = reactive({ name: null, description: null })
const saving = ref(false)
const serverError = ref('')

// COMPUTED
const isUserGroup = computed(() => !props.group || props.group.kind === 'user')
const preview = computed(() => {
  const base = props.group ?? { id: 'new', name: form.name || 'Grupo', kind: 'user' }
  const url = image.value === null ? (props.group?.imageUrl ?? null) : image.value || null
  return { ...groupAvatar({ ...base, name: form.name || base.name }), avatarUrl: base.kind === 'place' ? groupAvatar(base).avatarUrl : url }
})

// METHODS
const pickImage = async (event) => {
  const [picked] = await read([...event.target.files].slice(0, 1))
  event.target.value = ''
  if (picked) image.value = picked.dataUrl
}

const validateForm = () => {
  errors.name = firstError(rules.required(form.name, 'El nombre del grupo'), rules.max(form.name, LIMITS.groupName, 'El nombre del grupo'))
  errors.description = rules.max(form.description, LIMITS.groupDescription, 'La descripción')
  return !errors.name && !errors.description
}

const save = async () => {
  serverError.value = ''
  if (!validateForm()) return
  saving.value = true
  try {
    if (props.group) {
      await groups.updateGroup(props.group.id, { ...form })
      if (image.value !== null) await groups.setImage(props.group.id, image.value || null)
      emit('saved', props.group)
    } else {
      const created = await groups.createGroup({ ...form })
      if (image.value) await groups.setImage(created.id, image.value)
      emit('saved', created)
    }
    emit('close')
  } catch (e) {
    serverError.value = errorMessage(e)
  } finally {
    saving.value = false
  }
}

// WATCHERS
watch(
  () => props.open,
  (open) => {
    if (!open) return
    Object.assign(form, {
      name: props.group?.name ?? '',
      description: props.group?.description ?? '',
      secret: props.group?.privacy === 'secret',
    })
    image.value = null
    errors.name = null
    errors.description = null
    serverError.value = ''
  },
  { immediate: true },
)
</script>

<template>
  <BaseModal :open="open" :title="group ? 'Editar grupo' : 'Nuevo grupo'" :busy="saving" @close="emit('close')">
    <form id="group-form" class="form-grid" novalidate @submit.prevent="save">
      <div class="group-form__image">
        <UserAvatar :person="preview" size="lg" />
        <template v-if="isUserGroup">
          <input ref="fileInput" class="visually-hidden" type="file" :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="pickImage" />
          <button type="button" class="btn btn--secondary btn--sm" :disabled="processing" @click="fileInput?.click()">
            <ImagePlus aria-hidden="true" />
            {{ processing ? 'Revisando…' : preview.avatarUrl ? 'Cambiar imagen' : 'Añadir imagen' }}
          </button>
          <button v-if="preview.avatarUrl" type="button" class="btn btn--ghost btn--sm" @click="image = ''">
            <X aria-hidden="true" />
            Quitar
          </button>
        </template>
        <p v-else class="group-form__note">Los grupos de lugares llevan la bandera de su lugar.</p>
      </div>
      <div class="field">
        <label class="field__label" for="group-name">Nombre</label>
        <input
          id="group-name"
          v-model="form.name"
          class="input"
          :maxlength="LIMITS.groupName"
          placeholder="Montañeros de los domingos"
          :aria-invalid="!!errors.name || undefined"
          aria-describedby="group-name-error"
          :readonly="group?.kind === 'place'"
          autofocus
        />
        <p id="group-name-error" class="field__error">{{ errors.name }}</p>
      </div>

      <div class="field">
        <label class="field__label" for="group-description">Descripción</label>
        <textarea
          id="group-description"
          v-model="form.description"
          class="textarea"
          rows="3"
          :maxlength="LIMITS.groupDescription"
          placeholder="De qué va el grupo"
          aria-describedby="group-description-error"
        />
        <p id="group-description-error" class="field__error">{{ errors.description }}</p>
      </div>

      <fieldset v-if="!group || group.kind === 'user'" class="field group-privacy">
        <legend class="field__label">¿Quién puede encontrarlo?</legend>
        <label v-for="option in PRIVACY" :key="String(option.value)" class="group-privacy__option">
          <input v-model="form.secret" type="radio" name="group-privacy" :value="option.value" />
          <span>
            <strong>{{ option.label }}</strong>
            <span class="group-privacy__hint">{{ option.hint }}</span>
          </span>
        </label>
      </fieldset>

      <p v-if="!group" class="group-form__note">
        Lo que se publica dentro solo lo ven las personas del grupo. Si nadie se une en {{ GROUPS.emptyDays }} días, el grupo se elimina.
      </p>
      <p v-if="serverError" class="field__error" role="alert">{{ serverError }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="saving" @click="emit('close')">Cancelar</button>
      <button type="submit" form="group-form" class="btn btn--primary" :disabled="saving || processing">
        {{ saving ? 'Guardando…' : group ? 'Guardar cambios' : 'Crear grupo' }}
      </button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.group-privacy {
  display: flex;
  flex-direction: column;
  gap: $space-2;
  margin: 0;
  padding: 0;
  border: 0;

  &__option {
    display: flex;
    align-items: flex-start;
    gap: $space-2;
    padding: $space-2 $space-3;
    border: 1px solid $color-border;
    border-radius: $radius-sm;
    cursor: pointer;

    input {
      flex-shrink: 0;
      margin-top: 0.25rem;
      accent-color: $color-brand;
    }

    &:has(input:checked) {
      border-color: $color-brand;
      background: $color-brand-tint;
    }
  }

  &__hint {
    display: block;
    font-size: $fs-sm;
    color: $color-text-muted;
  }
}

.group-form__image {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: $space-2;
}

.group-form__note {
  font-size: $fs-sm;
  color: $color-text-muted;
}
</style>
