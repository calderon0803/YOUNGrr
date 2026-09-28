<script setup>
import { reactive, ref, watch } from 'vue'
import { ImagePlus, X } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import FriendPicker from '@/components/events/FriendPicker.vue'
import { useEventsStore } from '@/stores/events'
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
})

const emit = defineEmits(['close', 'saved'])

// STORES
const events = useEventsStore()

// DATA
const form = reactive({ title: '', description: '', imageUrl: null, date: '', time: '21:00', location: '' })
const invitees = ref([])
const errors = reactive({})
const saving = ref(false)
const serverError = ref('')
const fileInput = ref(null)
const { processing, read } = useImagePicker()

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
  return !Object.values(errors).some(Boolean)
}

const save = async () => {
  serverError.value = ''
  if (!validateForm()) return
  saving.value = true
  try {
    if (props.event) {
      await events.updateEvent(props.event.id, { ...form })
      emit('saved', props.event)
    } else {
      emit('saved', await events.createEvent({ ...form }, invitees.value))
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
    })
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
    grid-template-columns: 1fr 1fr;
    gap: $space-3;
  }
}
</style>
