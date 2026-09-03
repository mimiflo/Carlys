# @carlys/admin

Tableau de bord d'administration Next.js (App Router, Tailwind CSS, TanStack Query).

Voir le [README racine](../../README.md) et
[docs/architecture/admin.md](../../docs/architecture/admin.md).

## Commandes

```bash
pnpm dev        # http://localhost:3001
pnpm build      # build de production (standalone)
pnpm lint       # ESLint (config Next)
pnpm typecheck  # tsc --noEmit
pnpm test       # vitest + Testing Library
```

Étape 7 livrée : connexion administrateur réelle (`/login`, comptes séparés
des comptes mobiles, jeton à audience dédiée en sessionStorage), gestion des
utilisateurs (`/users` — recherche, fiche, suspension avec révocation des
sessions, attribution manuelle du premium) et journal d'audit (`/audit`).
Les réponses de l'API sont validées par les contrats Zod partagés
(`@carlys/api-contracts`) ; le contrôle d'accès réel reste côté serveur (RBAC
par permission), l'interface ne fait que refléter les refus (403).

Compte de développement (seed, jamais en production) :
`dev.admin@carlys.local` / `Carlys-Admin-2026!`.

## Pages publiques du produit

Le même serveur Next.js sert, dans le groupe de routes `src/app/(public)`
(mise en page propre, sans coquille d'administration ni lien vers `/login`),
les pages ouvertes depuis les e-mails et les retours de paiement :
`/verify-email`, `/reset-password`, `/abonnement/merci`, `/abonnement`,
`/privacy` et `/terms`. Les deux dernières rendent au build les fichiers
`docs/legal/privacy.md` et `docs/legal/terms.md` (lecteur Markdown minimal
maison, `src/lib/markdown.ts`, sans dépendance ni HTML injecté). Les appels
partent par `src/lib/public-api.ts`, sans jamais porter le jeton
d'administration ; `PUBLIC_APP_URL` côté API doit pointer sur cette
application (en local `http://localhost:3001`).
