# Architecture — tableau de bord d'administration (`apps/admin`)

Tableau de bord Next.js 16 (App Router) destiné à l'équipe Carlys :
supervision de la plateforme dès l'Étape 1, puis administration complète
(utilisateurs, contenus, abonnements) au fil des tranches verticales.

## Pile technique

| Brique | Choix | Remarques |
| --- | --- | --- |
| Framework | Next.js 16, App Router | `output: "standalone"` pour Docker |
| Langage | TypeScript strict | `tsc --noEmit` en CI |
| Styles | Tailwind CSS v4 | thème alimenté par les tokens Carlys |
| Données serveur | TanStack Query 5 | cache, retry, refetch |
| Formulaires | état React local + Zod (`zod/mini` sur les pages publiques) | aucune bibliothèque de formulaires : React Hook Form n'a jamais été installé (absent du lockfile) |
| Contrats API | `@carlys/api-contracts` | schémas Zod, consommés par leurs **sources** (voir « Poids des pages ») |
| Tests | vitest + Testing Library (jsdom) | `pnpm test` |
| Port | **3001** | `next dev --port 3001` / `next start --port 3001` |

## Structure `src/`

```
src/
├── app/
│   ├── layout.tsx        # layout racine (lang="fr", metadata, <Providers>)
│   ├── providers.tsx     # "use client" — QueryClientProvider TanStack Query
│   ├── globals.css       # Tailwind v4 + variables issues des design tokens
│   ├── page.tsx          # accueil : statut de la plateforme (interroge /health)
│   ├── login/            # connexion administrateur réelle (Étape 7)
│   ├── users/, users/[id]/, reports/, exercises/, categories/, media/, audit/
│   │                     # pages d'administration, réservées par permission
│   └── (public)/         # pages publiques du produit (voir plus bas)
├── components/           # coquille (AdminShell), statut API, cellules, panneaux
├── lib/                  # env.ts, transport, clients d'API, textes légaux
└── testing/              # jeux d'essai des tests
```

La liste exacte se relit (`ls apps/admin/src/app apps/admin/src/components`).
Les points qui suivent datent de l'Étape 1 et restent vrais :

- **`providers.tsx`** instancie un `QueryClient` unique
  (staleTime 30 s, retry 1, pas de refetch au focus) et enveloppe toute
  l'application.
- **`api-status.tsx`** interroge `GET {NEXT_PUBLIC_API_BASE_URL}/health`
  toutes les 15 s (endpoint hors préfixe `/api/v1`), accepte les réponses
  200 (ok) et 503 (dégradé) et **valide le corps** avec `healthReportSchema`
  de `@carlys/api-contracts` : aucune donnée de l'API n'est consommée sans
  passer par un schéma Zod.
- **`lib/env.ts`** est le seul point d'accès à `process.env` : les variables
  `NEXT_PUBLIC_*` étant inlinées au build, on ne les lit jamais directement
  dans les composants. Modèle dans `apps/admin/.env.example`
  (à copier vers `.env.local`).
- **`/login`** n'est plus un emplacement : depuis l'Étape 7, la connexion
  est réelle (section « Authentification admin » plus bas).

## Tailwind v4 et tokens Carlys

`globals.css` importe Tailwind (`@import "tailwindcss"`) et déclare les
couleurs Carlys en variables CSS, recopiées depuis
`packages/design-tokens/src/tokens.json` (primaire `#9B30FF`, accent
`#FF7A45`, neutres, sémantiques). Le bloc `@theme inline` les expose comme
couleurs Tailwind (`bg-primary`, `text-muted`, `bg-surface`…), et un bloc
`@media (prefers-color-scheme: dark)` fournit le thème sombre. Toute nouvelle
couleur passe par les tokens, jamais par une valeur en dur dans un composant.

**Recopiées, donc tenues par un test.** Rien n'importe le paquet de jetons
ici : `globals.css` est une copie manuelle, et elle avait déjà dérivé —
`--background` sombre valait `#0e0e1a` là où `surface.darkBackground` dit
`#08050E`, et `--surface` sombre `#171727` contre `#15101F`. Corrigé en
septembre 2026, et gardé depuis par
[`src/app/globals-tokens.test.ts`](../../apps/admin/src/app/globals-tokens.test.ts),
qui lit `tokens.json`, compare les deux blocs `:root` et échoue dans les deux
sens : une valeur qui s'écarte de son jeton, **et** une couleur ajoutée à la
main sans jeton en face. Ajouter une variable à `globals.css` suppose donc
d'ajouter sa correspondance dans le test — c'est voulu.

## Conventions (posées à l'Étape 1, appliquées ensuite)

- **Pages d'administration en composants client.** Toutes les pages
  derrière la coquille lisent et écrivent par TanStack Query, avec un jeton
  gardé dans l'onglet (`sessionStorage`) : elles sont donc `"use client"`,
  comme leurs cellules et panneaux (une vingtaine de fichiers :
  `grep -rl "'use client'" apps/admin/src --include=*.tsx`). Les composants
  serveur restent la règle là où rien n'est interactif : `layout.tsx`, les
  pages légales rendues au build, les pages publiques qui portent les
  métadonnées.
- **Lectures et mutations via TanStack Query** (`useQuery` / `useMutation`),
  avec invalidation explicite des clés après mutation ; pas de `fetch`
  dispersé dans les composants.
- **Formulaires en état React local**, validés avant envoi par les bornes et
  schémas de `@carlys/api-contracts` (`zod/mini` sur les pages publiques,
  pour leur poids) ; le serveur revalide tout. Aucune bibliothèque de
  formulaires : aucun formulaire du back-office n'en justifie une.
- **Réponses API toujours validées** par les schémas de
  `@carlys/api-contracts` avant usage.
- **Composants accessibles** : structure sémantique, `aria-labelledby`,
  `role="status"` pour les zones vivantes, états `focus-visible` — déjà
  appliqués sur la page d'accueil et le composant de statut.

## Authentification admin — Étape 7, séparée de l'auth utilisateur

L'authentification des administrateurs est un système **distinct** de
l'authentification des utilisateurs mobiles (Étape 2) : comptes, sessions et
surfaces d'attaque différents. Ce que l'Étape 7 a livré, et ce qui reste :

- comptes administrateurs avec **rôles et permissions** granulaires : livré ;
- **journal d'audit** : qui a fait quoi, quand, sur quoi : livré ; le
  « pourquoi » (une raison écrite) n'est exigé que pour **couper un accès
  premium**, et par le back-office seul (`premium-cut-form.tsx`) : l'API
  reçoit `reason` facultative et l'audit l'enregistre nulle à défaut ;
- **confirmation explicite + raison obligatoire** pour les autres actions
  sensibles : NON livré. La suspension d'un compte part en un geste, sans
  confirmation ni raison (`components/user-account-actions.tsx`) ;
  suppression de compte et remboursement n'ont pas de geste dans le
  back-office. Le modèle à suivre est la coupure premium (adm-1) ;
- protection des routes du tableau de bord côté serveur (middleware/layouts),
  jamais par simple masquage côté client : voir plus bas.

Depuis l'Étape 7, `/login` authentifie réellement (`adminApi.login`, puis
redirection vers la **première page que les permissions reçues autorisent**,
`firstAllowedRoute`) et le tableau de bord porte les pages accueil,
connexion, utilisateurs, fiche utilisateur, signalements, audit, exercices,
catégories et médias. La
protection reste à durcir côté serveur : elle passe aujourd'hui par le jeton
d'administration porté par les appels, pas par un middleware de route.

**Fin de session (septembre 2026).** Le jeton vit douze heures en
`sessionStorage`, et la coquille (`AdminShell`) ne vérifiait que sa
PRÉSENCE : un onglet resté ouvert, ou un compte désactivé, recevait des 401
partout, chaque page les traduisait à sa façon (« la permission audit:read
est requise », « reconnectez-vous si le problème persiste ») et rien ne
ramenait à la connexion. Désormais :

- `call` et `callUpload` (`lib/admin-api-client.ts`) traitent un **401 sur
  une requête qui portait un jeton** comme la fin de la session :
  `adminToken.expire()` oublie jeton et permissions et laisse une marque ;
- le jeton est un **magasin écouté** (`adminToken.subscribe`) : la coquille
  bascule aussitôt et renvoie vers `/login`, qui annonce « Ta session a
  expiré » ; une nouvelle connexion efface la marque ;
- la connexion part **sans** jeton (`requestJson(..., null)`) : un mot de
  passe faux (401) n'est jamais lu comme une fin de session ;
- la garde de la coquille consulte le STOCKAGE, pas la valeur rendue : à
  l'hydratation d'une page statique, l'instantané serveur vaut `null`, et
  l'effet renvoyait vers `/login` un administrateur connecté à chaque
  rechargement ;
- les erreurs de chargement se disent par leur CAUSE (`lib/load-error.ts`) :
  403 → la permission requise, 401 → session expirée, réseau → « le serveur
  ne répond pas », le reste → panne passagère.

**Gestes et permissions.** Les permissions reçues à la connexion
(`useAdminPermissions`) masquent la navigation ET les gestes : sans
`user:update`, la fiche ne propose pas « Suspendre le compte » mais dit
qu'il faut s'adresser à un super-administrateur (la page Signalements aussi,
puisque le rôle « support » la traite) ; sans `entitlement:grant`, aucun
geste premium. Ce n'est que de l'ergonomie : le serveur revérifie tout.

**En-têtes de sécurité.** `next.config.ts` pose sur TOUTES les routes
(`src/lib/security-headers.ts`) : une CSP (`default-src 'self'`,
`connect-src 'self'` + l'origine de `NEXT_PUBLIC_API_BASE_URL`,
`frame-ancestors 'none'`, `object-src 'none'`, `img-src https:` pour le
stockage objet, `http:` seulement pour un build sans TLS),
`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`,
`Referrer-Policy: no-referrer` (le lien de réinitialisation porte un secret
dans l'URL) et une `Permissions-Policy` fermée ; `poweredByHeader: false`.
`script-src` garde `'unsafe-inline'` : Next pose ses données de page dans
des scripts en ligne, et un nonce forcerait le rendu dynamique de chaque
page. Les en-têtes sont calculés AU BUILD, avec la même
`NEXT_PUBLIC_API_BASE_URL` que celle inlinée dans le client. Vérifié dans
Chromium : aucune violation sur les pages publiques et d'administration, et
un `fetch` vers un domaine tiers est bien refusé.

Côté API, la connexion admin est verrouillée comme la connexion mobile
(`LockoutService`, compteur `admin:<e-mail>` distinct) : au-delà de
`AUTH_MAX_LOGIN_ATTEMPTS` échecs, `429` pendant `AUTH_LOCKOUT_MINUTES`, sans
rien révéler du compte. Les gardes du back-office échouent **fermé** :
jeton absent ou invalide, compte désactivé, route sans `@RequirePermissions`
ou permission manquante, tout est refusé.

## Fonctionnalités cibles par domaine

Chaque ligne dit ce qui est livré et ce qui reste cible ; une ligne sans
« Livré » n'existe pas encore.

| Domaine | Cible |
| --- | --- |
| Utilisateurs | **Livré (partiel)** — `/users` (recherche) et fiche `/users/[id]` (identité, statut, adresse vérifiée ou non, droits et leur origine), suspension et réactivation (toutes les sessions révoquées, jetons push supprimés). Restent cibles : sessions par appareil dans la fiche, confirmation et raison pour la suspension, suppression d'un compte sur demande écrite |
| Abonnements (Étape 6+) | **Livré (partiel)** — la fiche montre l'ORIGINE de chaque droit (`source` : abonnement et son fournisseur, offert à la main, coupé à la main, jamais ouvert) et l'abonnement qui paie (`paidSubscription`). L'accès premium a trois gestes distincts (`components/user-premium-panel.tsx`) : « Offrir le premium » (octroi manuel), « Couper l'accès » (confirmation, raison obligatoire journalisée, avertissement quand un abonnement payé court : la coupure n'arrête pas la facturation et bloque les achats) et « Rendre la main à l'abonnement » (`DELETE /admin/users/:id/entitlements/:key`). Chaque geste vise TOUT le plan — chaque clé de `PREMIUM_ENTITLEMENT_KEYS`, coach IA et programmes illimités compris —, l'une après l'autre (`adminApi.setPremium`, `adminApi.releasePremium`) : un seul appel par clé, donc une entrée d'audit par clé. La route décide droit par droit, sans transaction commune ; un geste interrompu laisse un état partiel, que le panneau annonce « partiel » et que le même geste, idempotent, achève. Restent cibles : une décision de plan en une transaction côté API : historique Stripe/RevenueCat, remboursements, litiges |
| Exercices | **Livré (partiel)** — `/exercises` : catalogue publiés ET non publiés, recherche, « Charger la suite » (curseur, cinquante par page), publication/dépublication, photo (dépôt, remplacement, retrait), reclassement (brouillon repris de la liste à chaque ouverture et à l'annulation). Taxonomie : `/categories` crée, renomme et supprime les groupes musculaires (livré) ; le matériel reste en lecture seule. Reste cible : création/édition d'exercices |
| Programmes | création et édition de programmes d'entraînement, assignation, versions |
| Médias | **Livré (partiel)** — dépôt et rattachement depuis la page Exercices ; `/media` liste la bibliothèque (aperçus chargés à l'approche de l'écran) et supprime un média, avec confirmation. Reste cible : RÉUTILISER un média existant sur un autre exercice sans le redéposer |
| Notifications | campagnes push (après intégration FCM), modèles, ciblage, historique d'envoi |
| Webhooks (Étape 6+) | journal des webhooks Stripe/RevenueCat signés, statut de traitement idempotent, rejeu |
| Statistiques | tableaux de bord d'usage : inscriptions, rétention, séances, revenus |
| Modération | **Livré (partiel)** — `/reports` : signalements de la communauté (ouverts par défaut, motif, auteur et personne visée liés à leur fiche, colonne « Contenu visé » : l'encouragement, ou le défi entre amis (« Défi « titre » » puis le mot du créateur cité, ou « (sans message) »), clichés figés au signalement et lus via `encouragementMessage`, `friendChallengeTitle`, `friendChallengeMessage`), résolution et réouverture auditées, permission `community:moderate`. Reste cible : retrait d'un contenu par l'administration |

## Pages publiques du produit (`src/app/(public)`)

L'application héberge aussi les **pages web publiques** du produit, dans un
groupe de routes Next.js `(public)` doté de sa propre mise en page
(`layout.tsx` : en-tête sobre, pied de page avec les liens légaux, aucun lien
vers `/login`, aucune coquille d'administration) :

| Route | Contenu | Appel API |
| --- | --- | --- |
| `/reset-password?token=…` | formulaire nouveau mot de passe + confirmation, bornes du DTO (`PASSWORD_MIN_LENGTH` / `PASSWORD_MAX_LENGTH` de `@carlys/api-contracts/password-limits`, module sans Zod), états succès / lien expiré / saisie invalide / réseau | `POST /auth/reset-password` |
| `/verify-email?token=…` | vérification lancée à l'ouverture, états vérifié / lien invalide / réseau (avec « Réessayer ») | `POST /auth/verify-email` |
| `/abonnement/merci`, `/abonnement` | retours Stripe (succès / annulation), statiques | aucun |
| `/privacy`, `/terms` | `docs/legal/privacy.md` et `terms.md` rendus au build (`force-static`) | aucun |

Décisions :

- **Transport partagé** : `lib/api-transport.ts` (URL `/api/v1`, en-têtes,
  lecture du corps, enveloppe d'erreur → `ApiError`) sert au back-office
  (`lib/admin-api.ts`, avec le jeton ; il ré-exporte `ApiError` sous son nom
  historique `AdminApiError`) et aux pages publiques (`lib/public-api.ts`, qui
  n'envoie **jamais** le jeton d'administration, même présent dans l'onglet).
  Toujours aucun `fetch` dans un composant.
- **Client d'administration en trois fichiers**, pour qu'aucun ne devienne le
  fourre-tout de toutes les routes : `lib/admin-api-client.ts` (jeton,
  `call`/`callUpload`, lecture des enveloppes `parseData`/`parsePage`,
  `query`), `lib/admin-community-api.ts` (modération : les signalements ont
  leur page et leur permission) et `lib/admin-api.ts`, qui porte le reste des
  routes, **étale** la modération dans `adminApi` et ré-exporte le socle. Les
  pages n'importent donc toujours que `@/lib/admin-api`, et un domaine
  supplémentaire se pose à côté au lieu de faire grossir le même fichier.
- **Lecture de l'URL** (`useSearchParams`) dans un composant client sous
  `Suspense` ; la page reste un composant serveur porteur des métadonnées.
- **Vérification d'adresse par `useQuery`** (clé = jeton, `retry: false`,
  `staleTime` infini) plutôt qu'un effet : un jeton est à usage unique et ne
  doit être posté qu'une fois, même quand React monte deux fois le composant.
- **Markdown sans dépendance** : `lib/markdown.ts` lit le sous-ensemble employé
  par `docs/legal` (titres, paragraphes, listes, gras, liens) vers un arbre que
  `components/markdown-document.tsx` rend en éléments React, jamais en HTML
  injecté. Aucune bibliothèque Markdown n'existait dans le lockfile et le
  besoin tient en une centaine de lignes testées.
- **Fichiers légaux lus au build** depuis `docs/legal/`
  (`lib/legal-documents.ts`, chemin relatif à `process.cwd()` = `apps/admin`) :
  `.dockerignore` ré-inclut `docs/legal` et le `Dockerfile` le copie dans le
  contexte de build ; le conteneur final n'en a pas besoin.
- **Marqueurs `[À COMPLÉTER : …]`** : `next build` tourne toujours avec
  `NODE_ENV=production` (en CI comme dans l'image), donc `NODE_ENV` seul ne
  distingue pas une vérification d'un déploiement. L'image de production
  (`Dockerfile`) pose `LEGAL_PLACEHOLDERS=forbid` : son build **échoue** en
  listant les marqueurs restants ; un build de production ordinaire (CI,
  `pnpm build`) les liste en avertissement sans bloquer ; `next dev` rend le
  texte tel quel pour la relecture. Un test lit les deux vrais fichiers et
  refuse toute syntaxe que le lecteur minimal ignorerait (code, tableau,
  emphase à une étoile, lien mal fermé) ainsi que le vouvoiement.
  `admin-ci` relance le build avec `LEGAL_PLACEHOLDERS=forbid` dans une étape
  dédiée, **non bloquante** : elle remonte l'inventaire des marqueurs restants
  dans le résumé du job et en annotation, sans faire échouer la CI. Ce choix
  est délibéré — la garde bloque déjà là où elle protège vraiment (l'image de
  production, dont `images-ci` vérifie à chaque exécution qu'elle mord encore),
  et une CI rouge en permanence, le temps que les textes soient rédigés,
  n'apprendrait qu'à ne plus regarder `admin-ci`. L'étape échoue en revanche si
  le build casse pour une autre raison que les marqueurs. Le jour où
  `docs/legal` est complet, elle le signale et devient bloquante en une ligne.
- **Ton** : français, tutoiement, sans tiret cadratin dans les textes visibles
  (vérifié par les tests des pages légales). Le tutoiement de TOUS les
  écrans est tenu par `src/app/tone.test.ts`, qui refuse « vous », « votre »
  et les formes en -ez hors commentaires.
- `PUBLIC_APP_URL` (API) désigne cette application, jamais l'API.

## Poids des pages

Next 16 n'affiche plus le « First Load JS » : il se recalcule depuis
`.next/diagnostics/route-bundle-stats.json` (somme des chunks de chaque
route, brut et gzip -9). Mesures de septembre 2026 :

| Route | Avant | Après |
| --- | --- | --- |
| `/users` | 1160,9 Kio / 282,9 gzip | 802,5 / 216,1 |
| `/exercises` | 1169,9 / 285,4 | 813,5 / 218,7 |
| `/login` | 1149,2 / 279,2 | 790,6 / 212,2 |
| `/` | 873,7 / 217,3 | 781,1 / 209,2 |
| `/reset-password` | 1147,1 / 279,1 | 565,9 / 164,3 |
| `/verify-email` | 767,9 / 208,8 | 571,2 / 166,1 |

Deux causes, deux règles, tenues par `src/app/bundle-weight.test.ts` :

- **Les contrats se consomment par leurs SOURCES.** Publiés en CommonJS
  (`dist`), leur `require('zod')` résolvait `zod/index.cjs` alors que
  l'admin importait `zod/index.js` : deux instances complètes de Zod sur
  chaque page, plus tous les contrats sans élagage. `tsconfig.json` (et
  `vitest.config.ts`, pour que les tests lisent la même chose) pointe
  `@carlys/api-contracts` vers `packages/api-contracts/src/index.ts`, et le
  paquet déclare `"sideEffects": false`. L'API NestJS garde `dist`.
- **Les pages publiques ne chargent ni Zod « classique » ni les
  contrats.** Elles s'ouvrent sur téléphone depuis un e-mail :
  `lib/api-transport.ts` et le formulaire de réinitialisation passent par
  `zod/mini`, et les bornes de mot de passe viennent de
  `@carlys/api-contracts/password-limits`, un module sans Zod que `auth.ts`
  réexporte. Coût pour les pages d'administration : environ 2 Ko gzip.

## Accessibilité du clavier

Un geste qui REMPLACE le bouton activé (« Supprimer » qui devient
« Confirmer / Annuler », « modifier » qui ouvre un éditeur, « Annuler » qui
le referme) démontait le contrôle focalisé : le focus retombait sur
`<body>`. `components/use-focus-on-swap.ts` le pose sur le contrôle qui
prend la place (« Annuler » d'abord, jamais le geste destructeur ; le champ
Nom ; l'éditeur de catégories), et le rend au bouton d'origine à la
fermeture. Il ne bouge que sur un geste : un rafraîchissement de liste ne
vole jamais le focus. Le champ fichier caché des photos est hors de l'ordre
de tabulation (`tabIndex={-1}`) : c'est le bouton visible qui l'ouvre.

Quand le contrôle à focaliser n'apparaît qu'avec une donnée RAFRAÎCHIE
(« Restaurer » après une suppression, le titre « Accès premium : fermé »
après une coupure), la demande nomme l'état qu'elle attend
(`request('deleted')`) et le composant passe son état courant au crochet.
Demander le focus « après `invalidateQueries` » ne suffisait pas : React
Query livre la nouvelle donnée aux composants dans un `setTimeout(0)`,
souvent après la fin de la promesse, et le focus allait à l'ancien bouton,
démonté un instant plus tard. Une demande se sert une seule fois, et
seulement si le focus est perdu (sur `<body>`) : restée en attente parce que
la liste tardait, elle ne l'arrache pas à qui l'a posé ailleurs entre-temps.

## Tests

- `vitest.config.ts` : environnement `jsdom`, globals activés, alias `@ → src`
  et `@carlys/api-contracts` → sources du paquet (comme `tsconfig.json`),
  setup `vitest.setup.ts` (matchers `@testing-library/jest-dom`), fichiers
  `src/**/*.test.{ts,tsx}` colocalisés avec le code testé.
- Testing Library : on teste le comportement visible (rôles, textes,
  interactions), pas l'implémentation.
- `pnpm test` (dans `apps/admin`) ou `pnpm -r test` à la racine ; exécuté par
  le workflow `admin-ci` avec format, lint, typecheck et build — auxquels
  s'ajoutent le lint et les tests des paquets partagés
  (`pnpm --filter "./packages/**" lint` et `test`).

  `packages/ui` en fait partie, mais l'admin **ne le consomme pas** : c'est la
  déclinaison React du design system Flutter, maintenue pour la
  synchronisation Claude Design (`.design-sync/config.json`, arbitrage écrit
  dans `.design-sync/NOTES.md`). Le dépôt le dit à trois endroits — le
  `package.json` de l'admin ne liste aucun `@carlys/ui`, `pnpm-lock.yaml` ne
  lui connaît aucun importateur, et le `Dockerfile` installe
  `--filter "@carlys/admin..."`, dont la fermeture transitive l'exclut donc.
  `apps/admin/src/app/globals.css` acte la même absence : ses couleurs sont
  RECOPIÉES depuis `packages/design-tokens/src/tokens.json`, pas importées.
  L'adoption reste possible ; elle se déciderait à part, et ferait cesser
  cette recopie.

## Build standalone et Docker

`next.config.ts` active `output: "standalone"`. Le `Dockerfile`
(`apps/admin/Dockerfile`) est multi-stage avec pour contexte la **racine du
monorepo** :

```bash
docker build -f apps/admin/Dockerfile \
  --build-arg NEXT_PUBLIC_API_BASE_URL=http://localhost:3000 .
```

1. **build** : Node 22 alpine + corepack/pnpm, `pnpm install --frozen-lockfile
   --filter "@carlys/admin..."` (packages partagés inclus), puis build Next.
   `NEXT_PUBLIC_API_BASE_URL` est un argument de build car inliné dans le
   bundle client.
2. **runtime** : copie de `.next/standalone`, `.next/static` et `public`
   uniquement ; utilisateur non root `node`, port 3001, healthcheck HTTP sur
   `/`, démarrage par `node apps/admin/server.js`.

Dans le `docker-compose.yml` racine, le service `admin` (profil `app`)
construit cette image et dépend du service `api`.

## Documents liés

- [overview.md](./overview.md) — vue d'ensemble de la plateforme ;
- [backend.md](./backend.md) — architecture de l'API consommée par l'admin ;
- [`apps/admin/README.md`](../../apps/admin/README.md) — commandes du quotidien.
