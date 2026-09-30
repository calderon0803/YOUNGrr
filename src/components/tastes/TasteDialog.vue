<script setup>
import { computed, ref, useId, watch } from 'vue'
import { Search } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import StarRating from '@/components/tastes/StarRating.vue'
import { useTastesStore } from '@/stores/tastes'
import { useAuthStore } from '@/stores/auth'
import { catalogService } from '@/services/catalog.service'
import { errorMessage } from '@/services/errors'
import { debounce } from '@/utils/debounce'
import { CATALOGS, TASTES } from '@/config/app'

// Adds an artist, film or series from its catalogue, or changes the stars of
// one you already have. Films and series need stars (0.5 to 5); artists do not.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  kind: { type: String, required: true },
  /** A taste of yours to change its stars; null to add one. */
  taste: { type: Object, default: null },
})

const emit = defineEmits(['close'])

// STORES
const tastes = useTastesStore()
const auth = useAuthStore()

// DATA
const query = ref('')
const results = ref([])
const status = ref('idle')
const chosen = ref(null)
const rating = ref(null)
const saving = ref(false)
const error = ref('')
const inputId = useId()
let controller = null

// COMPUTED
const kindInfo = computed(() => TASTES.kinds.find((k) => k.key === props.kind))
const isArtist = computed(() => props.kind === 'artist')
const title = computed(() => (props.taste ? props.taste.title : kindInfo.value?.add))
const canSave = computed(() => !!chosen.value && (isArtist.value || !!rating.value) && !saving.value)
const credit = computed(() => (isArtist.value ? 'Datos de MusicBrainz' : 'Datos de TMDB. Este producto usa la API de TMDB, pero TMDB no lo avala ni lo certifica.'))

// METHODS
const search = debounce(async (q) => {
  controller?.abort()
  controller = new AbortController()
  status.value = 'loading'
  error.value = ''
  try {
    results.value = await catalogService.search(props.kind, q, { signal: controller.signal })
    status.value = 'success'
  } catch (e) {
    if (e?.name === 'AbortError') return
    status.value = 'error'
    error.value = errorMessage(e)
  }
}, CATALOGS.debounceMs)

const onInput = () => {
  chosen.value = null
  if (query.value.trim().length >= CATALOGS.minQueryLength) search(query.value)
  else results.value = []
}

const save = async () => {
  if (!canSave.value) return
  saving.value = true
  error.value = ''
  try {
    await tastes.set(auth.meId, props.kind, chosen.value, isArtist.value ? null : rating.value)
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
    query.value = ''
    results.value = []
    status.value = 'idle'
    error.value = ''
    chosen.value = props.taste ?? null
    rating.value = props.taste?.rating ?? null
  },
  { immediate: true },
)
</script>

<template>
  <BaseModal :open="open" :title="title" :busy="saving" @close="emit('close')">
    <div class="taste-dialog">
      <template v-if="!taste">
        <div class="taste-dialog__search">
          <Search class="taste-dialog__search-icon" aria-hidden="true" />
          <label class="visually-hidden" :for="inputId">Buscar</label>
          <input :id="inputId" v-model="query" class="input" type="search" placeholder="Buscar por nombre" autocomplete="off" autofocus @input="onInput" />
        </div>
        <p v-if="status === 'loading'" class="taste-dialog__muted">Buscando…</p>
        <p v-else-if="status === 'success' && !results.length" class="taste-dialog__muted">Sin resultados.</p>
        <ul v-if="results.length" class="taste-dialog__results" role="listbox" :aria-label="kindInfo?.label">
          <li
            v-for="item in results"
            :key="item.externalId"
            class="taste-dialog__result"
            :class="{ 'taste-dialog__result--chosen': chosen?.externalId === item.externalId }"
            role="option"
            :aria-selected="chosen?.externalId === item.externalId"
            tabindex="0"
            @click="chosen = item"
            @keydown.enter.prevent="chosen = item"
          >
            <img v-if="item.imagePath" class="taste-dialog__poster" :src="catalogService.imageUrl(item.imagePath)" alt="" loading="lazy" />
            <span class="taste-dialog__text">
              <strong>{{ item.title }}</strong>
              <span v-if="item.detail">{{ item.detail }}</span>
            </span>
          </li>
        </ul>
      </template>

      <div v-if="chosen && !isArtist" class="taste-dialog__rating">
        <p class="taste-dialog__label">¿Cuántas estrellas le das a <strong>{{ chosen.title }}</strong>?</p>
        <StarRating v-model="rating" editable size="lg" :label="`Estrellas para ${chosen.title}`" />
      </div>

      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
      <p class="taste-dialog__credit">{{ credit }}</p>
    </div>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="saving" @click="emit('close')">Cancelar</button>
      <button type="button" class="btn btn--primary" :disabled="!canSave" @click="save">{{ saving ? 'Guardando…' : 'Guardar' }}</button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.taste-dialog {
  display: flex;
  flex-direction: column;
  gap: $space-3;

  &__search {
    position: relative;

    .input {
      padding-left: 2rem;
    }
  }

  &__search-icon {
    position: absolute;
    top: 50%;
    left: $space-2;
    width: 1rem;
    height: 1rem;
    color: $color-text-soft;
    transform: translateY(-50%);
  }

  &__results {
    display: flex;
    flex-direction: column;
    gap: $space-1;
    max-height: 18rem;
    margin: 0;
    padding: 0;
    overflow-y: auto;
  }

  &__result {
    display: flex;
    align-items: center;
    gap: $space-3;
    padding: $space-2;
    border: 1px solid transparent;
    border-radius: $radius-sm;
    cursor: pointer;

    &:hover {
      background: $color-surface-hover;
    }

    &--chosen {
      border-color: $color-brand;
      background: $color-brand-tint;
    }
  }

  &__poster {
    flex-shrink: 0;
    width: 2.25rem;
    height: 3.375rem;
    border-radius: $radius-sm;
    object-fit: cover;
  }

  &__text {
    display: flex;
    flex-direction: column;
    min-width: 0;
    font-size: $fs-sm;

    span {
      color: $color-text-muted;
    }
  }

  &__rating {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: $space-2;
  }

  &__muted,
  &__credit {
    font-size: $fs-sm;
    color: $color-text-muted;
  }

  &__credit {
    font-size: $fs-xs;
  }
}
</style>
