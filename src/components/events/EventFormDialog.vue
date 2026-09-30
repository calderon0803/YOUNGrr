<script setup>
import { computed, reactive, ref, watch } from 'vue'
import { ImagePlus, X } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import FriendPicker from '@/components/events/FriendPicker.vue'
import { useEventsStore } from '@/stores/events'
import { useGroupsStore } from '@/stores/groups'
import { useImagePicker } from '@/composables/useImagePicker'
import { errorMessage } from '@/services/errors'
import { ACCEPTED_IMAGE_TYPES } from '@/utils/image'
import { LIMITS, firstError, rules } from '@/utils/validation'
import { toDateInput } from '@/utils/time'

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  /** Event to edit; null to create. */
  event: { type: Object, default: null },
  /** Creating from a group's page: { id, name }, an event of that group. */
  group: { type: Object, default: null },
})

const emit = defineEmits(['close', 'saved'])

// STORES
const events = useEventsStore()
const groups = useGroupsStore()

// DATA
const form = reactive({ title: '', description: '', imageUrl: null, date: '', time: '21:00', location: '', visibility: 'invite', groupId: '' })
const VISIBILITY = [
  { value: 'invite', label: 'Con invitación', hint: 'Solo lo ven las personas que invites.' },
  { value: 'public', label: 'Público', hint: 'Lo ven tus amigos y los amigos de tus amigos, con la lista de quién va, y pueden apuntarse sin invitación.' },
  { value: 'group', label: 'De un grupo', hint: 'Lo ven las personas del grupo, y pueden apuntarse sin invitación.' },
]
const invitees = ref([])
const errors = reactive({})
const saving = ref(false)
const serverError = ref('')
const fileInput = ref(null)
const { processing, read } = useImagePicker()

// COMPUTED
// The group of the event is chosen when creating it and does not change.
const fixedGroup = computed(() => props.event?.group ?? props.group)
const myGroups = computed(() => groups.mine.ids.map((id) => groups.groups[id]).filter(Boolean))
const options = computed(() => {
  if (props.event?.group) return VISIBILITY.filter((o) => o.value === 'group')
  if (props.event) return VISIBILITY.filter((o) => o.value !== 'group')
  return fixedGroup.value || myGroups.value.length ? VISIBILITY : VISIBILITY.filter((o) => o.value !== 'group')
})

// METHODS
const pickImage = async (event) => {
  const [image] = await read([...event.target.files].slice(0, 1))
  event.target.value = ''
  if (image) form.imageUrl = image.dataUrl
}

const validateForm = () => {
  errors.title = firstError(rules.required(form.title, 'El título'), rules.max(form.title, LIMITS.eventTitle, 'El título'))
  errors.date = rules.date(form.date)
  errors.time = rules.time(form.time)
  errors.location = firstError(rules.required(form.location, 'La ubicación'), rules.max(form.location, LIMITS.eventLocation, 'La ubicación'))
  errors.group = form.visibility === 'group' && !fixedGroup.value && !form.groupId ? 'Elige el grupo.' : null
  return !Object.values(errors).some(Boolean)
}

const toInput = () => {
  const { visibility, groupId, ...rest } = form
  const group = visibility === 'group' ? (fixedGroup.value?.id ?? groupId) : null
  return { ...rest, isPublic: visibility === 'public', groupId: group }
}

const save = async () => {
  serverError.value = ''
  if (!validateForm()) return
  saving.value = true
  try {
    if (props.event) {
      await events.updateEvent(props.event.id, toInput())
      emit('saved', props.event)
    } else {
      emit('saved', await events.createEvent(toInput(), invitees.value))
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
    const e = props.event
    Object.assign(form, {
      title: e?.title ?? '',
      description: e?.description ?? '',
      imageUrl: e?.imageUrl ?? null,
      date: e?.date ?? toDateInput(new Date(Date.now() + 7 * 86_400_000)),
      time: e?.time ?? '21:00',
      location: e?.location ?? '',
      visibility: fixedGroup.value ? 'group' : e?.isPublic ? 'public' : 'invite',
      groupId: '',
    })
    if (!props.event && !props.group && groups.mine.status === 'idle') groups.loadMine()
    invitees.value = []
    Object.keys(errors).forEach((k) => (errors[k] = null))
    serverError.value = ''
  },
  { immediate: true },
)
</script>

<template>
  <BaseModal :open="open" :title="event ? 'Editar evento' : 'Nuevo evento'" size="lg" :busy="saving" @close="emit('close')">
    <form id="event-form" class="form-grid" novalidate @submit.prevent="save">
      <div class="event-form__image">
        <img v-if="form.imageUrl" :src="form.imageUrl" alt="Imagen del evento" />
        <input ref="fileInput" class="visually-hidden" type="file" :accept="ACCEPTED_IMAGE_TYPES" tabindex="-1" aria-hidden="true" @change="pickImage" />
        <div class="event-form__image-actions">
          <button type="button" class="btn btn--secondary btn--sm" :disabled="processing" @click="fileInput?.click()">
            <ImagePlus aria-hidden="true" />
            {{ form.imageUrl ? 'Cambiar imagen' : 'Añadir imagen' }}
          </button>
          <button v-if="form.imageUrl" type="button" class="btn btn--ghost btn--sm" @click="form.imageUrl = null">
            <X aria-hidden="true" />
            Quitar
          </button>
        </div>
      </div>

      <div class="field">
        <label class="field__label" for="ev-title">Título</label>
        <input id="ev-title" v-model="form.title" class="input" :maxlength="LIMITS.eventTitle" placeholder="Cena de clase" :aria-invalid="!!errors.title || undefined" aria-describedby="ev-title-error" autofocus />
        <p id="ev-title-error" class="field__error">{{ errors.title }}</p>
      </div>

      <div class="event-form__row">
        <div class="field">
          <label class="field__label" for="ev-date">Fecha</label>
          <input id="ev-date" v-model="form.date" class="input" type="date" :aria-invalid="!!errors.date || undefined" aria-describedby="ev-date-error" />
          <p id="ev-date-error" class="field__error">{{ errors.date }}</p>
        </div>
        <div class="field">
          <label class="field__label" for="ev-time">Hora</label>
          <input id="ev-time" v-model="form.time" class="input" type="time" :aria-invalid="!!errors.time || undefined" aria-describedby="ev-time-error" />
          <p id="ev-time-error" class="field__error">{{ errors.time }}</p>
        </div>
      </div>

      <div class="field">
        <label class="field__label" for="ev-location">Ubicación</label>
        <input id="ev-location" v-model="form.location" class="input" :maxlength="LIMITS.eventLocation" placeholder="Bar, calle, ciudad" :aria-invalid="!!errors.location || undefined" aria-describedby="ev-location-error" />
        <p id="ev-location-error" class="field__error">{{ errors.location }}</p>
      </div>

      <fieldset class="field event-visibility">
        <legend class="field__label">¿Quién puede verlo?</legend>
        <label v-for="option in options" :key="option.value" class="event-visibility__option">
          <input v-model="form.visibility" type="radio" name="event-visibility" :value="option.value" />
          <span>
            <strong>{{ option.value === 'group' && fixedGroup ? `Del grupo «${fixedGroup.name}»` : option.label }}</strong>
            <span class="event-visibility__hint">{{ option.hint }}</span>
          </span>
        </label>
      </fieldset>

      <div v-if="form.visibility === 'group' && !fixedGroup" class="field">
        <label class="field__label" for="ev-group">Grupo</label>
        <select id="ev-group" v-model="form.groupId" class="select" :aria-invalid="!!errors.group || undefined" aria-describedby="ev-group-error">
          <option value="" disabled>Elige uno de tus grupos</option>
          <option v-for="g in myGroups" :key="g.id" :value="g.id">{{ g.name }}</option>
        </select>
        <p id="ev-group-error" class="field__error">{{ errors.group }}</p>
      </div>

      <div class="field">
        <label class="field__label" for="ev-description">Descripción</label>
        <textarea id="ev-description" v-model="form.description" class="textarea" rows="4" :maxlength="LIMITS.eventDescription" placeholder="Cuéntales el plan" />
      </div>

      <FriendPicker v-if="!event" v-model="invitees" />
      <p v-if="serverError" class="field__error" role="alert">{{ serverError }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="saving" @click="emit('close')">Cancelar</button>
      <button type="submit" form="event-form" class="btn btn--primary" :disabled="saving || processing">
        {{ saving ? 'Guardando…' : event ? 'Guardar cambios' : 'Crear evento' }}
      </button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.event-visibility {
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

.event-form {
  &__image {
    display: flex;
    flex-direction: column;
    gap: $space-2;

    img {
      width: 100%;
      aspect-ratio: 2.4;
      object-fit: cover;
      border-radius: $radius;
    }
  }

  &__image-actions {
    display: flex;
    gap: $space-2;
  }

  &__row {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: $space-3;
  }
}
</style>
