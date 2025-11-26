import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api/weather': {
        target: 'http://localhost:8123',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/weather/, ''),
      },
      '/api/customer': {
        target: 'http://localhost:18124',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/customer/, ''),
      },
    },
  },
})
