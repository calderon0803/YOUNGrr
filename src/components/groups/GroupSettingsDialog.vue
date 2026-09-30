<script setup>
import { computed, reactive, ref, watch } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { useGroupsStore } from '@/stores/groups'
import { errorMessage } from '@/services/errors'
import { GROUP_NOTIFY_OPTIONS, GROUP_SHARE_OPTIONS } from '@/utils/groups'

// Your privacy and notices in one group. Your friends always follow your
// friend settings; this only affects the people of the group who are not.

// PROPS
const props = defineProps({
  open: { type: Boolean, required: true },
  groupId: { type: String, required: true },
})

const emit = defineEmits(['close'])

// STORES
const groups = useGroupsStore()

// DATA
const form = reactive({ profileShare: 'basic', notify: 'all' })
const saving = ref(false)
const error = ref('')

// COMPUTED
const group = computed(() => groups.groups[props.groupId])
const isPlace = computed(() => group.value?.kind === 'place')
// Place groups only tell you about mentions.
const notifyOptions = computed(() =>
  isPlace.value ? [{ value: 'mentions', label: 'Solo cuando me mencionan' }, GROUP_NOTIFY_OPTIONS.at(-1)] : GROUP_NOTIFY_OPTIONS,
)

// METHODS
const save = async () => {
  saving.value = true
  error.value = ''
  try {
    await groups.setMySettings(props.groupId, { ...form })
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
    const mine = group.value?.mySettings
    form.profileShare = mine?.profileShare ?? 'basic'
    form.notify = isPlace.value && mine?.notify === 'all' ? 'mentions' : (mine?.notify ?? 'all')
    error.value = ''
  },
  { immediate: true },
)
</script>

<template>
  <BaseModal :open="open" title="Tu privacidad en este grupo" :busy="saving" @close="emit('close')">
    <form id="group-settings-form" class="group-settings" @submit.prevent="save">
      <fieldset class="group-settings__options">
        <legend class="group-settings__title">Qué ve de ti la gente del grupo que no es tu amiga</legend>
        <p class="group-settings__hint">Tus amigos siempre ven lo que permiten tus ajustes de amigos.</p>
        <label v-for="option in GROUP_SHARE_OPTIONS" :key="option.value" class="group-settings__option">
          <input v-model="form.profileShare" type="radio" name="group-share" :value="option.value" />
          <span>{{ option.label }}</span>
        </label>
      </fieldset>
      <fieldset class="group-settings__options">
        <legend class="group-settings__title">Avisos</legend>
        <label v-for="option in notifyOptions" :key="option.value" class="group-settings__option">
          <input v-model="form.notify" type="radio" name="group-notify" :value="option.value" />
          <span>{{ option.label }}</span>
        </label>
      </fieldset>
      <p v-if="error" class="field__error" role="alert">{{ error }}</p>
    </form>
    <template #footer>
      <button type="button" class="btn btn--secondary" :disabled="saving" @click="emit('close')">Cancelar</button>
      <button type="submit" form="group-settings-form" class="btn btn--primary" :disabled="saving">{{ saving ? 'Guardando…' : 'Guardar' }}</button>
    </template>
  </BaseModal>
</template>

<style lang="scss" scoped>
.group-settings {
  display: flex;
  flex-direction: column;
  gap: $space-4;

  &__options {
    display: flex;
    flex-direction: column;
    gap: $space-1;
    margin: 0;
    padding: 0;
    border: 0;
  }

  &__title {
    margin-bottom: $space-1;
    font-weight: 700;
  }

  &__hint {
    margin-bottom: $space-1;
    font-size: $fs-sm;
    color: $color-text-muted;
  }

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
}
</style>
