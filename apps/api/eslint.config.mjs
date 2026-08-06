// @ts-check
import base from '@carlys/eslint-config';
import globals from 'globals';

export default [
  { ignores: ['dist/**', 'coverage/**', 'eslint.config.mjs'] },
  ...base,
  {
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.jest,
      },
      sourceType: 'commonjs',
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
];
