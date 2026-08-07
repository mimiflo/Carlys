# Notes design-sync — Carlys

- Le design system « historique » de Carlys est en **Flutter**
  (`apps/mobile/lib/design_system/`) — non exploitable par Claude Design.
  `packages/ui` est sa déclinaison React, créée pour cette synchronisation
  (miroir des composants Flutter, CSS généré depuis
  `packages/design-tokens/src/tokens.json`).
- Monorepo pnpm : `react` n'est PAS hoisté à la racine — toujours passer
  `--node-modules ./packages/ui/node_modules` au convertisseur.
- Le package n'est pas installé sous `node_modules/@carlys/ui` (workspace) :
  toujours passer `--entry ./packages/ui/dist/index.js`.
- `cssEntry` doit rester `dist/carlys-ui.css` (fichier APLATI généré par
  `scripts/build-css.mjs`) — `dist/styles.css` n'est qu'un empilement
  d'`@import` que le convertisseur ne suit pas (`[CSS_PLACEHOLDER]`).
- Polices : Inter (400/500/600/700) + JetBrains Mono (400), sous-ensemble
  latin, **stockées dans le dépôt** (`packages/ui/src/fonts/`, licence OFL)
  et câblées via `extraFonts` — pas d'appel réseau au rendu.
- Environnement distant Claude Code : Chromium préinstallé build **1194**
  → installer `playwright@1.56.0` dans `.ds-sync/` (une autre version
  échoue avec « Executable doesn't exist »).
- `provider` = `CarlysProvider` : indispensable, il porte thème/fond/texte.
- Aperçus larges (EmptyState, ErrorState, Metric) : `cardMode: column`
  déjà en config suite à `[GRID_OVERFLOW]`.

## Risques de re-synchronisation

- **L'upload n'a jamais eu lieu** : l'autorisation Claude Design n'est pas
  disponible dans l'environnement distant (« /design-login requires an
  interactive terminal »). Aucun `projectId` en config. À la prochaine
  session AVEC autorisation : créer le projet (§1), puis upload atomique ou
  incrémental selon l'état — le bundle local `ds-bundle/` est complet,
  validé (render check 10/10) et noté (26 cellules « good »).
- Toute évolution de `tokens.json` doit repasser par
  `pnpm --filter @carlys/ui build` avant le convertisseur (CSS généré).
- Les aperçus utilisent des contenus fitness en français — les garder
  alignés avec le produit si les libellés changent.
- `packages/ui` n'est pas encore consommé par `apps/admin` — adoption
  possible mais hors périmètre de cette synchronisation.
