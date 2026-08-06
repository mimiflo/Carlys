# Docker

Les Dockerfiles vivent à côté de leur application, avec la racine du monorepo
comme contexte de build :

| Image  | Dockerfile              | Build                                      |
| ------ | ----------------------- | ------------------------------------------ |
| API    | `apps/api/Dockerfile`   | `docker build -f apps/api/Dockerfile .`    |
| Admin  | `apps/admin/Dockerfile` | `docker build -f apps/admin/Dockerfile .`  |

Le `docker-compose.yml` racine orchestre l'environnement local
(PostgreSQL, Redis, Mailpit, MinIO — et les apps via `--profile app`).

Ce dossier accueille les fichiers de support Docker transverses
(configurations partagées, scripts d'entrypoint) au fur et à mesure des
besoins.
