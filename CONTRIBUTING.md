# Contribuer à Carlys

Merci de contribuer à Carlys. Ce document décrit le flux de travail et les
exigences de qualité. Les règles détaillées de développement vivent dans
[CLAUDE.md](CLAUDE.md) et s'appliquent à toutes les contributions, humaines
comme assistées.

## Prérequis

- Node.js ≥ 22 et pnpm 10 (`corepack enable`) ;
- Docker (PostgreSQL, Redis, Mailpit, MinIO locaux) ;
- SDK Flutter stable (pour `apps/mobile`).

Installation : `./scripts/setup.sh` (ou suivre le [README](README.md)).

## Flux de travail

1. Créer une branche depuis `main` : `feat/<domaine>-<sujet>`,
   `fix/<domaine>-<sujet>`, `docs/<sujet>`, `chore/<sujet>`.
2. Développer en **tranche verticale** : schéma → API → tests → mobile/admin
   → documentation. Pas de fonctionnalité « à moitié branchée ».
3. Vérifier localement avant de pousser :

   ```bash
   ./scripts/check.sh          # build + format + lint + types + tests (TypeScript)
   cd apps/mobile && flutter analyze && flutter test   # si le mobile est touché
   ```

4. Ouvrir une pull request vers `main`. La CI (`api-ci`, `admin-ci`,
   `mobile-ci`, `security-ci`) doit être verte.

## Commits

- Messages à l'impératif, concis, en français ou anglais cohérent :
  `feat(api): ajoute le refresh token rotatif`.
- Un commit = un changement logique. Pas de commit « wip » sur `main`.
- Jamais de secret, de fichier `.env` réel ni de données personnelles dans
  un commit — voir [SECURITY.md](SECURITY.md).

## Exigences de qualité

Chaque pull request doit :

- inclure les tests correspondant à la nature du changement (unitaires,
  widget, intégration, e2e) — ne jamais supprimer un test pour faire passer
  une fonctionnalité ;
- gérer les états d'erreur, de chargement, d'absence de données et de perte
  de connexion pour tout écran ou endpoint touché ;
- respecter le design system (aucune valeur visuelle codée en dur) ;
- inclure les migrations Prisma nécessaires (`pnpm prisma:migrate`) ;
- mettre à jour la documentation impactée (`README.md`, `docs/`) ;
- passer `pnpm format:check`, `pnpm lint`, `pnpm typecheck` sans erreur ni
  suppression de règle non justifiée.

## Décisions d'architecture

Toute décision structurante (nouvelle bibliothèque significative, changement
de frontière de module, stratégie transverse) fait l'objet d'un ADR dans
[docs/decisions/](docs/decisions/) — voir le gabarit dans son README.

## Signalement de vulnérabilité

Ne jamais ouvrir d'issue publique pour une faille : suivre la procédure de
[SECURITY.md](SECURITY.md).
