<script setup>
import { computed } from 'vue'
import { Users } from 'lucide-vue-next'
import ActivityList from '@/components/feed/ActivityList.vue'
import StatusLine from '@/components/feed/StatusLine.vue'
import StateMessage from '@/components/common/StateMessage.vue'
import NotificationSummary from '@/components/notifications/NotificationSummary.vue'
import SuggestionsWidget from '@/components/friends/SuggestionsWidget.vue'
import PublicEventsWidget from '@/components/events/PublicEventsWidget.vue'
import YourGroupsWidget from '@/components/groups/YourGroupsWidget.vue'
import AchievementsToShare from '@/components/achievements/AchievementsToShare.vue'
import ModerationNotices from '@/components/moderation/ModerationNotices.vue'
import CalendarWidget from '@/components/events/CalendarWidget.vue'
import InviteWidget from '@/components/friends/InviteWidget.vue'
import { useFeedStore } from '@/stores/feed'
import { useAuthStore } from '@/stores/auth'
import { useUserStore } from '@/stores/user'

// STORES
const feed = useFeedStore()
const auth = useAuthStore()
const user = useUserStore()

// COMPUTED
const hasFriends = computed(() => (user.profiles[auth.meId]?.data?.friendsCount ?? 1) > 0)

// LIFECYCLE
user.loadProfile(auth.meId, { silent: true })
if (feed.home.status !== 'success' || feed.home.stale) feed.loadActivity()
</script>

<template>
  <div class="home">
    <h1 class="visually-hidden">Inicio</h1>

    <aside class="home__left" aria-label="Tus novedades, grupos, invitaciones y calendario">
      <NotificationSummary />
      <YourGroupsWidget />
      <InviteWidget />
      <CalendarWidget />
    </aside>

    <section class="home__center panel" aria-labelledby="feed-title">
      <h2 id="feed-title" class="panel-title">Novedades de tus amigos</h2>
      <ModerationNotices />
      <StatusLine />
      <ActivityList :list="feed.home" @retry="feed.loadActivity()" @more="feed.loadActivity({ more: true })">
        <template #empty>
          <StateMessage
            v-if="!hasFriends"
            :icon="Users"
            title="Todavía no tienes amigos."
            text="Busca personas para empezar. Aquí verás lo que hacen."
          >
            <RouterLink class="btn btn--primary" :to="{ name: 'friends', query: { tab: 'search' } }">Buscar personas</RouterLink>
          </StateMessage>
          <StateMessage
            v-else
            title="Tus amigos no han hecho nada estos días."
            text="Cuando cambien su estado, suban fotos o hagan nuevos amigos, aparecerá aquí."
          />
        </template>
      </ActivityList>

    </section>

    <aside class="home__right" aria-label="Personas que quizá conozcas y planes públicos">
      <AchievementsToShare />
      <SuggestionsWidget />
      <PublicEventsWidget />
    </aside>

  </div>
</template>

<style lang="scss" scoped>
.home {
  display: flex;
  flex-direction: column;
  gap: $space-3;

  &__left,
  &__right {
    display: flex;
    flex-direction: column;
    gap: $space-3;
    min-width: 0;
  }

  &__center {
    min-width: 0;
    overflow: hidden;
    border-radius: 0;
    border-right: 0;
    border-left: 0;
  }
}

/* Media queries */

@media (min-width: $bp-tablet) {
  .home {
    display: grid;
    grid-template-columns: 15rem minmax(0, 1fr);
    // The first row fits the left column; the second takes the rest of the
    // feed's height, so the right column sits just below instead of far down.
    grid-template-rows: auto 1fr;
    grid-template-areas:
      'left center'
      'right center';
    align-items: start;
    gap: $space-4;

    &__left {
      grid-area: left;
    }

    &__right {
      grid-area: right;
    }

    &__center {
      grid-area: center;
      border-right: 1px solid $color-border;
      border-left: 1px solid $color-border;
      border-radius: $radius;
    }
  }
}

@media (min-width: $bp-desktop) {
  .home {
    grid-template-columns: 15rem minmax(0, 1fr) 14.5rem;
    grid-template-rows: auto;
    grid-template-areas: 'left center right';
  }
}
</style>
