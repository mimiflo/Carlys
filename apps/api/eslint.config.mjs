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
  {
    // Le tableau « Tailles de fichiers » de CLAUDE.md devient exécutable ici.
    // Comptage PAR DÉFAUT, blancs et commentaires compris : c'est la lecture
    // littérale du tableau (« Service < 300 lignes »), et surtout la seule qui
    // colle à `wc -l` — un auteur vérifie sa marge sans lancer ESLint. Les trois
    // autres modes ont été mesurés (skipBlankLines, skipComments, les deux) :
    // tous à dette nulle eux aussi, mais aucun ne se relit dans l'éditeur.
    // Quand le plafond tombe, la réponse attendue par CLAUDE.md est de DÉCOUPER,
    // jamais de contourner.
    //
    // Le `files:` s'arrête à src/** : apps/api/prisma/catalog.ts fait 2949 lignes
    // de données déclaratives et n'a rien à faire sous ce plafond.
    files: ['src/**/*.service.ts'],
    rules: { 'max-lines': ['error', { max: 300, skipBlankLines: false, skipComments: false }] },
  },
  {
    files: ['src/**/*.controller.ts'],
    rules: { 'max-lines': ['error', { max: 200, skipBlankLines: false, skipComments: false }] },
  },
];
