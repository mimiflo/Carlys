# Déploiement

Stratégie de déploiement de Carlys — cadre posé à l'Étape 1, mise en œuvre
avec la première release.

## Environnements

| Environnement | Rôle                          | Base de données     | Déploiement            |
| ------------- | ----------------------------- | ------------------- | ---------------------- |
| development   | poste développeur             | Docker local        | manuel                 |
| test          | CI                            | éphémère (services) | à chaque pipeline      |
| staging       | recette proche production     | PostgreSQL managé   | automatique depuis main|
| production    | utilisateurs réels            | PostgreSQL managé   | manuel après validation|

## Principes

- images Docker multi-stage vérifiées en CI par le workflow `images-ci`
  (construction des trois cibles, garde légale exercée, et DÉMARRAGE réel de
  l'image de l'API sur `/health/live`) ; la publication d'images taguées par
  SHA vers un registre reste à mettre en place avec le staging ;
- `prisma migrate deploy` exécuté comme étape distincte AVANT le basculement
  du trafic — jamais automatiquement au démarrage du conteneur ;
- configuration exclusivement par variables d'environnement, validée au
  démarrage (le serveur refuse de démarrer sinon) ; en production, les
  valeurs de développement de `S3_*`, `SMTP_HOST`, `EMAIL_FROM`,
  `PUBLIC_APP_URL` et `CORS_ORIGINS` sont refusées elles aussi
  (`docs/security/reverse-proxy.md`, section 2) ;
- l'API tourne derrière un reverse proxy : `TRUST_PROXY_HOPS` doit valoir le
  nombre exact de proxys devant elle (`1` pour un Nginx unique, voir
  `infrastructure/nginx/carlys.conf.example`), sinon rate limiting,
  verrouillage et audit ne voient que l'adresse du proxy
  (`docs/security/reverse-proxy.md`) ;
- Redis managé et stockage objet (S3/Cloudflare R2) par environnement ;
- sauvegardes PostgreSQL automatiques + test de restauration régulier ;
- health checks (`/health/ready`) branchés sur l'orchestrateur ;
- pas de déploiement automatique en production sans validation humaine.

## Migrations : avant la bascule, jamais au démarrage

L'image d'exécution de l'API ne contient pas le CLI Prisma : c'est une
dépendance de développement, absente de l'arbre de production. Le `Dockerfile`
de l'API expose donc une seconde cible, `migrate`, construite AVANT la
fabrication de cet arbre : CLI Prisma, `schema.prisma` et
`prisma/migrations/` y sont présents, et son point d'entrée est
`prisma migrate deploy`. Elle tourne en utilisateur `node`, sans télémétrie
(`CHECKPOINT_DISABLE=1`).

### Comment l'arbre de production est fabriqué

L'image d'exécution est bâtie sur `pnpm deploy --filter=@carlys/api --prod
--legacy`, qui produit un répertoire autonome : dépendances de production
seules, liens de workspace résolus en vraies copies. `pnpm prune --prod` ne
convient PAS à ce monorepo — cadré sur le projet racine, ni récursif ni
filtré, et le `package.json` racine n'ayant aucune dépendance de production,
il vidait `apps/api/node_modules` et faisait disparaître
`@carlys/api-contracts` et `@carlys/shared-config`, qui sont pourtant des
dépendances de production de l'API. L'image se construisait et mourait au
démarrage.

Corollaire à retenir : `pnpm deploy` reconstruit `node_modules` depuis le
store, donc le **client Prisma engendré au `prebuild` n'y survit pas**. Le
`Dockerfile` le régénère dans l'arbre déployé. Toute évolution de cet étage
doit le vérifier — `images-ci` le fait en interrogeant `/health/ready`, qui
touche réellement la base.

Ordre d'un déploiement, pour chaque environnement :

```bash
# 1. Construire les deux images depuis le même commit (racine du monorepo).
docker build -f apps/api/Dockerfile -t carlys-api:$SHA .
docker build -f apps/api/Dockerfile --target migrate -t carlys-api-migrate:$SHA .

# 2. Appliquer les migrations. Un code de sortie non nul ARRÊTE le déploiement.
docker run --rm -e DATABASE_URL="$DATABASE_URL" carlys-api-migrate:$SHA

# 3. Seulement ensuite : démarrer / recharger l'API et basculer le trafic
#    (health check /health/ready).
```

Le conteneur d'exécution ne joue jamais de migration : un redémarrage ou une
mise à l'échelle ne doit pas modifier le schéma. Avec un orchestrateur, la
même image `migrate` se déclare en tâche ponctuelle (job, `initContainer`,
service Compose à profil dédié) dont le succès conditionne le déploiement de
l'API.

Les manifestes concrets (Terraform, fichiers de plateforme, workflows de
déploiement) seront ajoutés ici lors de la mise en place du staging.

## Pages web publiques et `PUBLIC_APP_URL`

L'application Next.js (`apps/admin`) ne sert pas que le back-office : son
groupe de routes `src/app/(public)` porte les **pages publiques du produit**,
avec leur propre mise en page (sans coquille d'administration ni lien vers
`/login`) :

| Route | Rôle |
| --- | --- |
| `/verify-email?token=…` | cible du lien de vérification d'adresse ; poste `POST /api/v1/auth/verify-email` |
| `/reset-password?token=…` | cible du lien « mot de passe oublié » ; poste `POST /api/v1/auth/reset-password` |
| `/abonnement/merci`, `/abonnement` | retours Stripe (`success_url` / `cancel_url`), statiques |
| `/privacy`, `/terms` | politique de confidentialité et conditions d'utilisation, rendues au build depuis `docs/legal/` |

En conséquence, pour chaque environnement déployé :

- **`PUBLIC_APP_URL` (API)** doit désigner l'URL publique de cette
  application web (par exemple `https://admin.carlys.example`, ou un hôte
  dédié qui proxie le même conteneur), **jamais** l'URL de l'API : c'est la
  base des liens envoyés par e-mail et des URL de retour Stripe. En local :
  `http://localhost:3001`.
- **`CORS_ORIGINS` (API)** doit contenir cette même origine : les pages
  appellent l'API depuis le navigateur.
- Le build de l'image admin lit `docs/legal/*.md` : le contexte Docker est la
  racine du dépôt et `.dockerignore` ré-inclut `docs/legal` (le conteneur
  final n'en a pas besoin : les pages sont statiques).
- Les magasins d'applications exigent une URL de politique de
  confidentialité : c'est `${PUBLIC_APP_URL}/privacy`.
- Les textes légaux portent des marqueurs `[À COMPLÉTER : …]` (raison
  sociale, adresse de contact, délais de conservation…) à renseigner avant
  toute mise en production. Le `Dockerfile` de l'admin pose
  `LEGAL_PLACEHOLDERS=forbid` : tant qu'un marqueur subsiste, le build de
  l'image **échoue** en les listant. Une image locale ou de recette peut
  passer outre avec `--build-arg LEGAL_PLACEHOLDERS=allow` (c'est ce que fait
  le `docker-compose.yml` racine), jamais une image de production.
