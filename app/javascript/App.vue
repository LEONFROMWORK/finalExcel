<template>
  <div id="app">
    <Toast />
    <MainLayout v-if="showLayout">
      <router-view />
    </MainLayout>
    <router-view v-else />
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import MainLayout from './components/MainLayout.vue'
import Toast from 'primevue/toast'

const route = useRoute()

// Pages that should not show the layout
const noLayoutPages = ['login', 'register']

const showLayout = computed(() => {
  return !noLayoutPages.includes(route.name)
})
</script>

<style>
/* Global styles */
#app {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* Reset some defaults */
* {
  box-sizing: border-box;
}

body {
  margin: 0;
  padding: 0;
}

/* Utility classes for animations */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.slide-fade-enter-active {
  transition: all 0.3s ease-out;
}

.slide-fade-leave-active {
  transition: all 0.3s cubic-bezier(1.0, 0.5, 0.8, 1.0);
}

.slide-fade-enter-from,
.slide-fade-leave-to {
  transform: translateX(20px);
  opacity: 0;
}
</style>