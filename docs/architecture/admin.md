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

Jusque-là, `/login` reste un emplacement documenté et aucune page ne prétend
être protégée.

## Fonctionnalités cibles par domaine

Aucune de ces fonctionnalités n'existe à l'Étape 1 ; elles arrivent avec les
tranches verticales correspondantes, l'essentiel de la surface d'admin étant
livré à l'Étape 7.

| Domaine | Cible |
| --- | --- |
| Utilisateurs | recherche, fiche détaillée, sessions par appareil, suspension/réactivation avec raison |
| Abonnements (Étape 6+) | état des entitlements (source d'autorité serveur), historique Stripe/RevenueCat, remboursements, litiges |
| Exercices (Étape 3+) | CRUD du catalogue, taxonomie (groupes musculaires, matériel), publication/dépublication, invalidation du cache Redis |
| Programmes | création et édition de programmes d'entraînement, assignation, versions |
| Médias | bibliothèque S3 (`carlys-media`), upload, remplacement, purge |
| Notifications | campagnes push (après intégration FCM), modèles, ciblage, historique d'envoi |
| Webhooks (Étape 6+) | journal des webhooks Stripe/RevenueCat signés, statut de traitement idempotent, rejeu |
| Statistiques | tableaux de bord d'usage : inscriptions, rétention, séances, revenus |
| Modération (future) | signalements et contenus sociaux, une fois les fonctionnalités sociales livrées |

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
