<script setup>
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import UserAvatar from '@/components/common/UserAvatar.vue'
import { useAuthStore } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { errorMessage } from '@/services/errors'

// STORES
const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const toast = useToast()

// DATA
const accounts = ref([])
const pendingId = ref(null)

// METHODS
const enter = async (id) => {
  pendingId.value = id
  try {
    await auth.loginDemo(id)
    router.replace(typeof route.query.next === 'string' ? route.query.next : { name: 'home' })
  } catch (e) {
    toast.error(errorMessage(e))
  } finally {
    pendingId.value = null
  }
}

// LIFECYCLE
onMounted(async () => {
  accounts.value = await auth.listDemoAccounts()
})
</script>

<template>
  <section v-if="auth.isLocalBackend && accounts.length" class="demo" aria-labelledby="demo-title">
    <h2 id="demo-title" class="demo__title">Prueba YOUNGrr con una cuenta de demostración</h2>
    <ul class="demo__list" role="list">
      <li v-for="person in accounts" :key="person.id">
        <button type="button" class="demo__account" :disabled="pendingId !== null" @click="enter(person.id)">
          <UserAvatar :person="person" size="lg" />
          <span>{{ pendingId === person.id ? 'Entrando…' : person.firstName }}</span>
        </button>
      </li>
    </ul>
  </section>
</template>

<style lang="scss" scoped>
.demo {
  &__title {
    @include section-title;
    margin-bottom: $space-3;
  }

  &__list {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: $space-2;
    margin: 0;
  }

  &__account {
    @include reset-button;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: $space-1;
    width: 100%;
    padding: $space-2 $space-1;
    border-radius: $radius;
    font-size: $fs-sm;
    font-weight: 600;

    &:hover:not(:disabled) {
      background: $color-brand-tint;
      color: $color-brand-strong;
    }

    &:disabled {
      opacity: 0.6;
      cursor: wait;
    }
  }
}
</style>
