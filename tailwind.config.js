/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/javascript/**/*.{js,vue}',
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './node_modules/primevue/**/*.{vue,js,ts,jsx,tsx}'
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        'primary': '#f97316', // Orange 500 - matching your brand
        'primary-dark': '#ea580c', // Orange 600
        'primary-light': '#fb923c', // Orange 400
      }
    }
  },
  plugins: [
    require('tailwindcss-primeui')
  ],
  corePlugins: {
    preflight: false // Prevent conflicts with PrimeVue base styles
  }
}