import react from '@vitejs/plugin-react';
import path from 'node:path';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  resolve: {
    // Mêmes chemins que tsconfig.json : les tests lisent les SOURCES des
    // contrats, comme le build, et jamais un `dist` qui aurait pris du retard.
    // Le plus précis d'abord : un alias est un préfixe.
    alias: [
      {
        find: /^@carlys\/api-contracts\/password-limits$/,
        replacement: path.resolve(__dirname, '../../packages/api-contracts/src/password-limits.ts'),
      },
      {
        find: /^@carlys\/api-contracts$/,
        replacement: path.resolve(__dirname, '../../packages/api-contracts/src/index.ts'),
      },
      { find: /^@\//, replacement: `${path.resolve(__dirname, 'src')}/` },
    ],
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
  },
});
