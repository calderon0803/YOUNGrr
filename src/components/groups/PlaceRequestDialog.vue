<script setup>
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import BaseModal from '@/components/common/BaseModal.vue'
import CityPicker from '@/components/common/CityPicker.vue'
import { useGroupsStore } from '@/stores/groups'
import { errorMessage } from '@/services/errors'
import { PLACE_GROUPS } from '@/config/app'

// "Quiero un grupo de…": the town is picked from the list of the geocoder, so
// each one has a single group. Only how many asked is shown, never who.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  /** A town to start with ({ name }): the picker searches it. */
  initial: { type: Object, default: null },
})

const emit = defineEmits(['close'])

// STORES
const groups = useGroupsStore()
const router = useRouter()

// DATA
const place = ref(null)
const status = ref(null)
const loading = ref(false)
const busy = ref(false)
const error = ref('')

// COMPUTED
const outOfSpain = computed(() => !!place.value && place.value.country !== 'es')
const threshold = computed(() => status.value?.threshold ?? PLACE_GROUPS.threshold)

// METHODS
const run = async (action) => {
  busy.value = true
  error.value = ''
  try {
    await action()
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    busy.value = false
  }
}

const ask = () => run(async () => (status.value = await groups.requestPlace(place.value)))

const cancel = () =>
  run(async () => {
    await groups.cancelPlaceRequest(place.value.key)
    status.value = await groups.placeStatus(place.value.key)
  })

const openGroup = () => {
  emit('close')
  router.push({ name: 'group', params: { id: status.value.group.id } })
}

// WATCHERS
watch(place, async (value) => {
  status.value = null
  error.value = ''
  if (!value?.key || value.country !== 'es') return
  loading.value = true
  try {
    status.value = await groups.placeStatus(value.key)
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    loading.value = false
  }
})

watch(
  () => props.open,
  (open) => {
    if (!open) return
    place.value = null
    status.value = null
    error.value = ''
  },
)
</script>

<template>
  <BaseModal :open="open" title="El grupo de tu pueblo" :busy="busy" @close="emit('close')">
    <div class="place-request">
      <p class="place-request__intro">
        Los grupos de pueblos y ciudades se crean cuando {{ PLACE_GROUPS.threshold }} personas los piden, para que no haya grupos vacíos.
        Las peticiones duran {{ PLACE_GROUPS.requestDays }} días.
      </p>
      <CityPicker :key="String(open)" v-model="place" label="Pueblo o ciudad" :hint="initial?.name ? `Busca «${initial.name}» y elígelo de la lista.` : ''" />

      <p v-if="outOfSpain" class="place-request__status">Por ahora solo hay grupos de lugares de España.</p>
      <p v-else-if="loading" class="place-request__status">Comprobando…</p>
      <template v-else-if="status">
        <template v-if="status.group">
          <p class="place-request__status">
            Ya existe el grupo de <strong>{{ status.group.name }}</strong>.
          </p>
          <button type="button" class="btn btn--primary" @click="openGroup">{{ status.group.myRole ? 'Ir al grupo' : 'Ver el grupo' }}</button>
        </template>
        <template v-else>
          <p class="place-request__status">
            <strong>{{ status.count }} de {{ threshold }}</strong> personas han pedido el grupo de {{ place.name }}.
          </p>
          <button v-if="!status.requested" type="button" class="btn btn--primary" :disabled="busy" @click="ask">Quiero un grupo de {{ place.name }}</button>
          <div v-else class="place-request__asked">
            <span>Ya lo has pedido. Te avisaremos cuando se cree.</span>
            <button type="button" class="btn btn--ghost btn--sm" :disabled="busy" @click="cancel">Retirar mi petición</button>
          </div>
        </template>
      </template>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </div>
  </BaseModal>
</template>

<style lang="scss" scoped>
.place-request {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: $space-3;

  > :deep(.field) {
    align-self: stretch;
  }

  &__intro,
  &__status {
    font-size: $fs-sm;
  }

  &__intro {
    color: $color-text-muted;
  }

  &__asked {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: $space-2;
    font-size: $fs-sm;
  }
}
</style>
