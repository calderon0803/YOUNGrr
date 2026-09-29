<script setup>
// Checkbox to accept the terms of use and the privacy policy. The links open in
// a new tab so the form being filled in is not lost.

// PROPS
defineProps({
  id: { type: String, required: true },
  error: { type: String, default: '' },
})

const accepted = defineModel({ type: Boolean, required: true })
</script>

<template>
  <div class="field">
    <label class="check consent" :for="id">
      <input :id="id" v-model="accepted" type="checkbox" :aria-invalid="!!error || undefined" :aria-describedby="`${id}-error`" />
      <span>
        He leído y acepto las
        <RouterLink :to="{ name: 'terms' }" target="_blank">condiciones de uso</RouterLink>
        y la
        <RouterLink :to="{ name: 'privacy' }" target="_blank">política de privacidad</RouterLink>.
      </span>
    </label>
    <p :id="`${id}-error`" class="field__error">{{ error }}</p>
  </div>
</template>

<style lang="scss" scoped>
.consent {
  align-items: flex-start;

  input {
    flex-shrink: 0;
    margin-top: 0.2rem;
  }
}
</style>
