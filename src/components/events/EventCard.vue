<script setup>
import { MapPin } from 'lucide-vue-next'
import EventDateBadge from '@/components/events/EventDateBadge.vue'
import { plural } from '@/utils/text'

// PROPS
defineProps({
  event: { type: Object, required: true },
})

// DATA
const STATUS_LABEL = { going: 'Asistirás', maybe: 'Quizás', declined: 'No asistirás', pending: 'Sin responder' }
</script>

<template>
  <li class="event-card">
    <RouterLink class="event-card__link" :to="{ name: 'event', params: { id: event.id } }">
      <span class="event-card__image">
        <img v-if="event.imageUrl" :src="event.imageUrl" alt="" loading="lazy" />
      </span>
      <span class="event-card__body">
        <EventDateBadge :date="event.date" />
        <span class="event-card__text">
          <span class="event-card__title">{{ event.title }}</span>
          <span class="event-card__meta">
            {{ event.time }} ·
            <MapPin aria-hidden="true" />
            {{ event.location }}
          </span>
          <span class="event-card__meta">
            {{ plural(event.counts.going, 'asistente', 'asistentes') }} · Organiza {{ event.isCreator ? 'tú' : event.creator.firstName }}
          </span>
        </span>
        <span v-if="event.myStatus" class="event-card__status" :class="`event-card__status--${event.myStatus}`">
          {{ STATUS_LABEL[event.myStatus] }}
        </span>
      </span>
    </RouterLink>
  </li>
</template>

<style lang="scss" scoped>
.event-card {
  &__link {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    color: $color-text;
    background: $color-surface;
    border: 1px solid $color-border;
    border-radius: $radius;

    &:hover {
      text-decoration: none;
      border-color: $color-border-strong;

      .event-card__title {
        text-decoration: underline;
      }
    }
  }

  &__image {
    display: block;
    aspect-ratio: 2.4;
    background: $color-brand-soft;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__body {
    display: flex;
    align-items: flex-start;
    gap: $space-3;
    padding: $space-3;
  }

  &__text {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
  }

  &__title {
    font-weight: 700;
    font-size: $fs-md;
    line-height: 1.25;
  }

  &__meta {
    @include truncate;
    font-size: $fs-sm;
    color: $color-text-muted;

    svg {
      display: inline-block;
      width: 0.85rem;
      height: 0.85rem;
      vertical-align: -0.1em;
    }
  }

  &__status {
    flex-shrink: 0;
    padding: 0.1rem $space-2;
    border-radius: $radius-sm;
    font-size: $fs-xs;
    font-weight: 700;
    background: $color-surface-hover;
    color: $color-text-muted;

    &--going {
      background: $color-success-soft;
      color: $color-success;
    }

    &--maybe {
      background: $color-brand-tint;
      color: $color-brand-strong;
    }

    &--pending {
      background: $color-grr-soft;
      color: $color-grr-strong;
    }
  }
}
</style>
