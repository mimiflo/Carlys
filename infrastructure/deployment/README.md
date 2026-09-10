# Déploiement

Stratégie de déploiement de Carlys — cadre posé à l'Étape 1, mise en œuvre
avec la première release.

## Environnements

| Environnement | Rôle                      | Base de données       | Déploiement                       |
| ------------- | ------------------------- | --------------------- | --------------------------------- |
| development   | poste développeur         | Docker local          | manuel (`docker-compose.yml`)     |
| test          | CI                        | éphémère (services)   | à chaque pipeline                 |
| staging       | recette proche production | PostgreSQL du serveur | `deploy.sh staging <sha12>`       |
| production    | utilisateurs réels        | PostgreSQL du serveur | `promote.sh` (validation humaine) |

`staging` et `production` cohabitent sur **un seul serveur dédié**, isolés par
leur projet Compose et leurs volumes, derrière un Nginx d'hôte. Les six
sous-domaines, les ports de boucle locale et l'arborescence `/srv/carlys/` sont
décrits par le **[guide de mise en route](../../docs/deployment/mise-en-route-serveur.md)**,
qui se suit d'un serveur nu jusqu'à l'application publiée.

Ce Nginx d'hôte **n'est pas en façade d'Internet et ne termine pas le TLS** :
les six noms publics pointent en DNS vers le reverse proxy réseau
`gra6.luuc.fr`, qui détient les certificats et relaie en HTTP interne vers le
serveur Carlys, lequel écoute en HTTP sur le port 80 uniquement. Le serveur ne
génère aucun certificat, n'installe pas Certbot et ne sert aucun défi ACME.
Les URL publiques restent en `https://` — HTTPS existe toujours, il est
seulement terminé un cran plus haut. Conséquences complètes et mesurées :
[`docs/security/reverse-proxy.md`](../../docs/security/reverse-proxy.md).

## Principes

- images Docker multi-stage vérifiées en CI par le workflow `images-ci`
  (construction des trois cibles, garde légale exercée, et DÉMARRAGE réel de
  l'image de l'API sur `/health/live`), puis **publiées** vers GHCR, taguées
  par SHA, par `images-publish` (voir « Le registre » plus bas) ;
- `prisma migrate deploy` exécuté comme étape distincte AVANT le basculement
  du trafic — jamais automatiquement au démarrage du conteneur ;
- configuration exclusivement par variables d'environnement, validée au
  démarrage (le serveur refuse de démarrer sinon) ; en production, les
  valeurs de développement de `S3_*`, `SMTP_HOST`, `EMAIL_FROM`,
  `PUBLIC_APP_URL` et `CORS_ORIGINS` sont refusées elles aussi
  (`docs/security/reverse-proxy.md`, section 5) ;
- l'API tourne derrière **deux** reverse proxys — gra6 puis le Nginx de l'hôte
  décrit par `infrastructure/nginx/` : `TRUST_PROXY_HOPS` doit donc valoir `2`
  (mesuré sur la chaîne réelle : à `1`, `req.ip` vaut l'adresse de gra6 pour
  tout le trafic, et limitation de débit comme audit deviennent aveugles).
  Le compteur ne suffit pas : gra6 doit **écraser** `X-Forwarded-For`
  (`proxy_set_header X-Forwarded-For $remote_addr`), faute de quoi n'importe
  quel client se fait passer pour n'importe quelle adresse — l'exigence, les
  trois cas mesurés et le pourquoi sont dans
  `docs/security/reverse-proxy.md` ;
- **le port 80 du serveur ne doit être joignable que depuis gra6** (prérequis
  de pare-feu) : le Nginx de l'hôte pose `X-Forwarded-Proto: https` en dur,
  donc un accès direct obtiendrait de l'API un `req.secure = true` mensonger,
  sans être passé par l'écrasement ci-dessus ;
- Redis et stockage objet par environnement — sur le serveur dédié, un Redis
  et un MinIO par projet Compose ; un service managé (S3, Cloudflare R2)
  s'y substitue sans changer autre chose que les variables `S3_*` ;
- sauvegardes PostgreSQL automatiques + test de restauration régulier ;
- health checks (`/health/ready`) : c'est sur cette route que `deploy.sh`
  attend, en boucle bornée, avant de considérer une bascule réussie ;
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

## Le registre : trois images, un SHA, deux tags admin

Les images sont publiées dans GHCR. **On déploie un SHA, jamais un tag
mouvant** : la promotion recette → production redéploie exactement les mêmes
octets, faute de quoi « ce qui a été éprouvé » et « ce qui tourne » cesseraient
d'être la même chose sans qu'on puisse dire quand.

| Image | Tag | Produite par |
| ----- | --- | ------------ |
| `ghcr.io/mimiflo/carlys-api` | `sha-<sha12>` | `images-publish` (poussée) |
| `ghcr.io/mimiflo/carlys-api-migrate` | `sha-<sha12>` | `images-publish` (poussée) |
| `ghcr.io/mimiflo/carlys-admin` | `sha-<sha12>` | `images-publish` — garde légale desserrée, **recette seulement** |
| `ghcr.io/mimiflo/carlys-admin` | `sha-<sha12>-prod` | `images-publish-prod` (`workflow_dispatch`) — garde légale **armée** |

Un tag mouvant `staging` suit la branche de travail, pour lire d'un coup d'œil
ce qui est récent dans l'onglet Packages. Aucun déploiement ne s'en sert.

`images-publish` tourne à **chaque** poussée sur les deux branches, **sans
filtre de chemins** — à rebours des CI de code, et par conséquence directe du
déploiement par SHA : le SHA qu'un opérateur a sous la main est celui de la
tête de branche, et il doit avoir ses images. Un filtre qui n'aurait rien
publié pour un commit ne touchant que `infrastructure/` ou `scripts/` ferait
échouer `deploy.sh` sur ce SHA — image absente —, sur le serveur, sur une
cause qu'aucun message n'y nomme. Un filtre `paths` convient à une porte qui
rend un avis sur un commit ; pas à un producteur d'artefacts adressés par
commit. Le coût est borné par le cache de couches GHA et par le `concurrency`
du workflow ; les vieux tags `sha-…` se purgent depuis l'onglet Packages.

### Pourquoi l'admin a deux images pour un seul commit

Ce n'est pas une commodité, c'est une nécessité, et pour deux raisons
indépendantes :

1. **La garde légale.** `apps/admin/Dockerfile` pose
   `LEGAL_PLACEHOLDERS=forbid` : tant que `docs/legal/*.md` portent un marqueur
   `[À COMPLÉTER : …]`, le build échoue en les listant. Une image de recette
   doit pouvoir exister avant que ces textes soient rédigés, d'où le
   desserrage — jamais pour la production.
2. **L'adresse de l'API est figée dans le bundle du navigateur.**
   `NEXT_PUBLIC_API_BASE_URL` n'est pas lue à l'exécution : Next.js la remplace
   *au build* (`apps/admin/src/lib/env.ts`, lu par le composant `'use client'`
   `api-status.tsx`). L'image de recette vise `api-staging.DOMAINE`, celle de
   production `api.DOMAINE` — deux binaires différents, nécessairement. C'est
   aussi pourquoi les workflows exigent la variable de dépôt `CARLYS_DOMAIN` et
   échouent bruyamment sans elle : sans elle, l'image publiée enverrait le
   navigateur vers `http://localhost:3000`, se construirait sans erreur,
   démarrerait sans erreur, et serait muette.

Les images `carlys-api` et `carlys-api-migrate`, elles, ne portent ni adresse
ni texte : leur configuration est entièrement d'exécution. Elles sont donc
construites **une seule fois** et servent aux deux environnements.

### Exploitation

Les scripts du serveur (`scripts/server/`) et le fichier Compose unique
(`infrastructure/server/compose.yml`) enchaînent tout cela :
`setup.sh` prépare la machine, `deploy.sh <env> <sha12>` migre puis bascule,
`promote.sh` porte un SHA de la recette vers la production après confirmation,
`backup.sh` sauvegarde. La marche à suivre complète, avec ce que chaque étape
doit répondre pour être réussie, est dans le
**[guide de mise en route](../../docs/deployment/mise-en-route-serveur.md)**.

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
  application web — `https://app.DOMAINE` en production,
  `https://app-staging.DOMAINE` en recette —, **jamais** l'URL de l'API :
  c'est la base des liens envoyés par e-mail et des URL de retour Stripe. En
  local : `http://localhost:3001`.
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
