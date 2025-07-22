import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'
import RubyPlugin from 'vite-plugin-ruby'
import { resolve } from 'path'

export default defineConfig({
  plugins: [RubyPlugin(), vue()],
  test: {
    globals: true,
    environment: 'jsdom',
    root: '.',
    setupFiles: ['./test/javascript/setup.js'],
    include: ['test/javascript/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'],
    coverage: {
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'test/',
        '**/*.d.ts',
        '**/*.config.*',
        '**/mockData.js',
      ],
    },
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, './app/javascript'),
    },
  },
})