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
| Formulaires | React Hook Form + Zod (`@hookform/resolvers`) | installés, conventions ci-dessous |
| Contrats API | `@carlys/api-contracts` | schémas Zod des enveloppes et de `/health` |
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
│   ├── page.test.tsx     # test vitest colocalisé
│   └── login/
│       └── page.tsx      # emplacement documenté — PAS de fausse authentification
├── components/
│   └── api-status.tsx    # "use client" — useQuery sur /health, validation Zod
└── lib/
    └── env.ts            # lecture centralisée des variables NEXT_PUBLIC_*
```

Points notables de l'Étape 1 :

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
- **`/login`** documente l'emplacement de l'authentification administrateur
  sans la simuler : pas de formulaire factice qui prétendrait fonctionner.

## Tailwind v4 et tokens Carlys

`globals.css` importe Tailwind (`@import "tailwindcss"`) et déclare les
couleurs Carlys en variables CSS, recopiées depuis
`packages/design-tokens/src/tokens.json` (primaire `#9B30FF`, accent
`#FF7A45`, neutres, sémantiques). Le bloc `@theme inline` les expose comme
couleurs Tailwind (`bg-primary`, `text-muted`, `bg-surface`…), et un bloc
`@media (prefers-color-scheme: dark)` fournit le thème sombre. Toute nouvelle
couleur passe par les tokens, jamais par une valeur en dur dans un composant.

## Conventions (posées à l'Étape 1, appliquées ensuite)

- **Server Components par défaut.** `"use client"` uniquement quand
  nécessaire (état, hooks, interactivité) — aujourd'hui `providers.tsx` et
  `api-status.tsx` seulement.
- **Lectures et mutations via TanStack Query** (`useQuery` / `useMutation`),
  avec invalidation explicite des clés après mutation ; pas de `fetch`
  dispersé dans les composants.
- **Formulaires en React Hook Form + Zod** (`@hookform/resolvers`) : le même
  schéma valide côté client et sert de contrat avec l'API.
- **Réponses API toujours validées** par les schémas de
  `@carlys/api-contracts` avant usage.
- **Composants accessibles** : structure sémantique, `aria-labelledby`,
  `role="status"` pour les zones vivantes, états `focus-visible` — déjà
  appliqués sur la page d'accueil et le composant de statut.

## Authentification admin — Étape 7, séparée de l'auth utilisateur

L'authentification des administrateurs est un système **distinct** de
l'authentification des utilisateurs mobiles (Étape 2) : comptes, sessions et
surfaces d'attaque différents. Cible de l'Étape 7 :

- comptes administrateurs avec **rôles et permissions** granulaires ;
- **confirmation explicite + raison obligatoire** pour les actions sensibles
  (suppression de compte, remboursement, bannissement…) ;
- **journal d'audit** : qui a fait quoi, quand, sur quoi, et pourquoi ;
- protection des routes du tableau de bord côté serveur (middleware/layouts),
  jamais par simple masquage côté client.

Depuis l'Étape 7, `/login` authentifie réellement (`adminApi.login`, puis
redirection vers `/users`) et le tableau de bord porte les pages accueil,
connexion, utilisateurs, fiche utilisateur, signalements, audit, exercices,
catégories et médias. La
protection reste à durcir côté serveur : elle passe aujourd'hui par le jeton
d'administration porté par les appels, pas par un middleware de route.

Côté API, la connexion admin est verrouillée comme la connexion mobile
(`LockoutService`, compteur `admin:<e-mail>` distinct) : au-delà de
`AUTH_MAX_LOGIN_ATTEMPTS` échecs, `429` pendant `AUTH_LOCKOUT_MINUTES`, sans
rien révéler du compte. Les gardes du back-office échouent **fermé** :
jeton absent ou invalide, compte désactivé, route sans `@RequirePermissions`
ou permission manquante, tout est refusé.

## Fonctionnalités cibles par domaine

Aucune de ces fonctionnalités n'existe à l'Étape 1 ; elles arrivent avec les
tranches verticales correspondantes, l'essentiel de la surface d'admin étant
livré à l'Étape 7.

| Domaine | Cible |
| --- | --- |
| Utilisateurs | recherche, fiche détaillée, sessions par appareil, suspension/réactivation avec raison |
| Abonnements (Étape 6+) | état des entitlements (source d'autorité serveur), historique Stripe/RevenueCat, remboursements, litiges |
| Exercices | **Livré (partiel)** — `/exercises` : catalogue publiés ET non publiés, recherche, publication/dépublication, photo (dépôt, remplacement, retrait). Restent cibles : création/édition d'exercices et taxonomie |
| Programmes | création et édition de programmes d'entraînement, assignation, versions |
| Médias | **Livré (partiel)** — dépôt et rattachement depuis la page Exercices ; l'API porte déjà la bibliothèque complète (`GET/DELETE /admin/media`). Reste cible : un écran de bibliothèque autonome, pour réutiliser une photo sans la redéposer |
| Notifications | campagnes push (après intégration FCM), modèles, ciblage, historique d'envoi |
| Webhooks (Étape 6+) | journal des webhooks Stripe/RevenueCat signés, statut de traitement idempotent, rejeu |
| Statistiques | tableaux de bord d'usage : inscriptions, rétention, séances, revenus |
| Modération | **Livré (partiel)** — `/reports` : signalements de la communauté (ouverts par défaut, motif, auteur et personne visée liés à leur fiche, encouragement visé), résolution et réouverture auditées, permission `community:moderate`. Reste cible : retrait d'un contenu par l'administration |

## Pages publiques du produit (`src/app/(public)`)

L'application héberge aussi les **pages web publiques** du produit, dans un
groupe de routes Next.js `(public)` doté de sa propre mise en page
(`layout.tsx` : en-tête sobre, pied de page avec les liens légaux, aucun lien
vers `/login`, aucune coquille d'administration) :

| Route | Contenu | Appel API |
| --- | --- | --- |
| `/reset-password?token=…` | formulaire nouveau mot de passe + confirmation, bornes du DTO (`PASSWORD_MIN_LENGTH` / `PASSWORD_MAX_LENGTH` de `@carlys/api-contracts`), états succès / lien expiré / saisie invalide / réseau | `POST /auth/reset-password` |
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
- **Ton** : français, tutoiement, sans tiret cadratin dans les textes visibles
  (vérifié par les tests des pages légales).
- `PUBLIC_APP_URL` (API) désigne cette application, jamais l'API.

## Tests

- `vitest.config.ts` : environnement `jsdom`, globals activés, alias `@ → src`,
  setup `vitest.setup.ts` (matchers `@testing-library/jest-dom`), fichiers
  `src/**/*.test.{ts,tsx}` colocalisés avec le code testé.
- Testing Library : on teste le comportement visible (rôles, textes,
  interactions), pas l'implémentation.
- `pnpm test` (dans `apps/admin`) ou `pnpm -r test` à la racine ; exécuté par
  le workflow `admin-ci` avec format, lint, typecheck et build.

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
