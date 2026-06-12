import { defineConfig } from 'vite';

// Порт фиксирован: src-tauri/tauri.conf.json → devUrl http://localhost:8006
export default defineConfig({
  base: './', // относительные пути: Tauri + веб из подпапки
  clearScreen: false,
  server: {
    port: 8006,
    strictPort: true,
    watch: { ignored: ['**/src-tauri/**'] },
  },
});
