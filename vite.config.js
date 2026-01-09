import { defineConfig } from 'vite'
import { plugin as elm } from 'vite-plugin-elm'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    tailwindcss(),
    elm()
  ],
  root: './',
  publicDir: 'static',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        main: './index.html'
      }
    }
  },
  server: {
    port: 3000,
    proxy: {
      '/upload': 'http://localhost:5001',
      '/save': 'http://localhost:5001',
      '/options': 'http://localhost:5001'
    }
  }
})
