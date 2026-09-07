// @ts-check
import eslint from '@eslint/js';
import eslintConfigPrettier from 'eslint-config-prettier';
import tseslint from 'typescript-eslint';

/**
 * Configuration de base partagée par tous les projets TypeScript du monorepo.
 * Chaque projet la complète avec ses globals (node, jest, browser…) et son
 * `parserOptions.tsconfigRootDir`.
 */
export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    rules: {
      // Les journaux passent par Pino côté API (corrélés au requestId) : un
      // `console.log` nu sortait de ce circuit sans que rien ne l'arrête.
      // `warn` reste ouvert — apps/admin/src/lib/legal-documents.ts s'en sert
      // délibérément pour avertir au build qu'un document légal garde des
      // marqueurs à compléter. Mesuré : `no-console` nu = 1 violation (celle-là),
      // avec `allow: ['warn']` = zéro sur tout le monorepo.
      'no-console': ['error', { allow: ['warn'] }],
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      '@typescript-eslint/consistent-type-imports': [
        'error',
        { prefer: 'type-imports', fixStyle: 'inline-type-imports' },
      ],
    },
  },
  eslintConfigPrettier,
);
