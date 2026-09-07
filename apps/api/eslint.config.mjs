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
  {
    // « Ne jamais accéder à Prisma depuis un contrôleur NestJS » (CLAUDE.md).
    // Aucun des 30 contrôleurs ne le faisait ; rien ne l'empêchait pour autant.
    // Pas d'`allowTypeImports` : même en type seul, le modèle de persistance n'a
    // pas à traverser la couche HTTP — les formes exposées viennent de
    // packages/api-contracts. Si un contrôleur croit avoir besoin d'un type
    // Prisma, la sortie est de le réexporter depuis le module, pas de désactiver
    // la règle.
    files: ['src/**/*.controller.ts'],
    rules: {
      '@typescript-eslint/no-restricted-imports': [
        'error',
        {
          paths: [
            {
              name: '@prisma/client',
              message:
                'Un contrôleur ne touche pas Prisma : passe par le service ou le repository du module, et expose les formes de packages/api-contracts.',
            },
          ],
          patterns: [
            {
              group: ['**/prisma.service', './prisma.service', '**/prisma/prisma.service'],
              message:
                "Un contrôleur n'injecte pas PrismaService : l'accès aux données passe par le service ou le repository du module.",
            },
          ],
        },
      ],
    },
  },
];
