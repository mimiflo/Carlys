// @ts-check
import base from '@carlys/eslint-config';

export default [
  {
    ignores: ['dist/**', 'eslint.config.mjs', 'vitest.config.ts', 'vitest.setup.ts', 'scripts/**'],
  },
  ...base,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
];
