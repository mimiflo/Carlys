// @ts-check
import base from '@carlys/eslint-config';

export default [
  { ignores: ['dist/**', 'eslint.config.mjs'] },
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
