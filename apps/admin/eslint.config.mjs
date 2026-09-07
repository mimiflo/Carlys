// @ts-check
import base from '@carlys/eslint-config';
import { defineConfig, globalIgnores } from 'eslint/config';
import nextVitals from 'eslint-config-next/core-web-vitals';
import nextTs from 'eslint-config-next/typescript';

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // La base partagée du monorepo s'empile ici comme dans les cinq autres projets.
  // Sans elle `eslint --print-config` rendait `no-empty = undefined` côté admin :
  // un `try { … } catch {}` vide y passait lint ET typecheck, alors que le même
  // fichier dans packages/ui rendait « Empty block statement  no-empty ».
  ...base,
  {
    languageOptions: {
      parserOptions: {
        // eslint.config.mjs et postcss.config.mjs n'appartiennent à aucun tsconfig ;
        // sans cette permission le service de projet les refuse (« was not found by
        // the project service ») au lieu de les analyser. Les cinq autres projets
        // les excluent — ici on préfère les garder couverts.
        projectService: { allowDefaultProject: ['*.mjs'] },
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    // Deux règles de `recommendedTypeChecked` visent, dans un projet React, des
    // pièges qui n'y existent pas. Mesuré sur le dépôt : elles ne signalaient que
    // des idiomes corrects, jamais un vrai défaut. Le reste de la base s'applique.
    rules: {
      // `onSubmit={handler}` avec un handler `async` : React ignore la promesse,
      // mais le handler capture déjà ses propres erreurs. La vérification reste
      // active partout ailleurs (retours de fonction, arguments, propriétés).
      '@typescript-eslint/no-misused-promises': [
        'error',
        { checksVoidReturn: { attributes: false } },
      ],
      // `queryFn: adminApi.overview`, `useSyncExternalStore(…, adminToken.get, …)` :
      // méthodes d'objets littéraux qui ne touchent jamais `this`, donc sans risque
      // de portée. La règle n'a pas d'option pour distinguer ce cas.
      '@typescript-eslint/unbound-method': 'off',
    },
  },
  globalIgnores(['.next/**', 'out/**', 'build/**', 'coverage/**', 'next-env.d.ts']),
]);

export default eslintConfig;
