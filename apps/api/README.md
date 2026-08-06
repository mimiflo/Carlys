# @carlys/api

Backend NestJS de Carlys — monolithe modulaire (PostgreSQL + Prisma, Redis, Pino, Swagger).

Voir le [README racine](../../README.md) pour l'installation complète et
[docs/architecture/backend.md](../../docs/architecture/backend.md) pour l'architecture.

## Commandes

```bash
pnpm dev                # démarrage en mode watch (nécessite docker compose up -d)
pnpm build              # prisma generate + nest build
pnpm test               # tests unitaires
pnpm test:e2e           # tests end-to-end
pnpm lint               # ESLint
pnpm typecheck          # tsc --noEmit
pnpm prisma:generate    # génération du client Prisma
pnpm prisma:migrate     # migrations en développement
pnpm prisma:seed        # seed de développement
```

## Endpoints techniques

| Endpoint        | Rôle                                        |
| --------------- | ------------------------------------------- |
| `GET /health`   | État complet (PostgreSQL, Redis)            |
| `GET /health/live`  | Liveness                                |
| `GET /health/ready` | Readiness                               |
| `GET /metrics`  | Prometheus (protégé en production)          |
| `GET /api/docs` | Swagger (désactivé par défaut en production)|

Les routes métier sont versionnées sous `/api/v1`.
