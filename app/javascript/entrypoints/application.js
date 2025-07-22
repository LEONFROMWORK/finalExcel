import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from '@/router'
import App from '@/App.vue'
import PrimeVue from 'primevue/config'
import Aura from '@primeuix/themes/aura'
import Tooltip from 'primevue/tooltip'
import ToastService from 'primevue/toastservice'

// Import Tailwind styles
import '@/styles/application.css'

// Import PrimeVue styles
import 'primeicons/primeicons.css'

// Turbo Rails integration
import * as Turbo from '@hotwired/turbo'
Turbo.start()

// Create Vue app
const app = createApp(App)

// Configure PrimeVue with Aura theme
app.use(PrimeVue, {
  theme: {
    preset: Aura,
    options: {
      prefix: 'p',
      darkModeSelector: '.dark',
      cssLayer: {
        name: 'primevue',
        order: 'tailwind-base, primevue, tailwind-utilities'
      }
    }
  },
  ripple: true
})

// Use plugins
app.use(createPinia())
app.use(router)
app.use(ToastService)

// Register PrimeVue directives
app.directive('tooltip', Tooltip)

// Mount the app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  const appElement = document.getElementById('app')
  if (appElement) {
    app.mount('#app')
  }
})
