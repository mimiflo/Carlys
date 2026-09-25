# Docker

Les Dockerfiles vivent à côté de leur application, avec la racine du monorepo
comme contexte de build :

| Image  | Dockerfile              | Build                                      |
| ------ | ----------------------- | ------------------------------------------ |
| API    | `apps/api/Dockerfile`   | `docker build -f apps/api/Dockerfile .`    |
| Admin  | `apps/admin/Dockerfile` | `docker build -f apps/admin/Dockerfile .`  |

Exception : **MinIO et `mc`**, construits depuis leurs sources faute d'images
officielles, ont leur propre contexte — `infrastructure/minio/` (`docker build
--target minio infrastructure/minio`, ou `--target mc`). Voir
`infrastructure/minio/README.md`.

Le `docker-compose.yml` racine orchestre l'environnement local
(PostgreSQL, Redis, Mailpit, MinIO — et les apps via `--profile app`).

Ce dossier accueille les fichiers de support Docker transverses
(configurations partagées, scripts d'entrypoint) au fur et à mesure des
besoins.
