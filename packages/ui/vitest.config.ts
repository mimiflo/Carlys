import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    // globals: nécessaire au nettoyage automatique de @testing-library/react.
    globals: true,
    include: ['src/**/*.test.{ts,tsx}'],
    setupFiles: ['./vitest.setup.ts'],
    // Vitest remplace toute feuille de styles par une chaîne vide, `?raw`
    // compris ; `contrast.test.ts` lit celle des composants telle qu'elle
    // est écrite, pour en mesurer les paires.
    css: { include: [/styles\/components\.css/] },
  },
});
