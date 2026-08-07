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
