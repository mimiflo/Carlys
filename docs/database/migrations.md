# Migrations Prisma : une migration publiée ne se réécrit pas

## La règle

Une migration **publiée** — poussée sur `development` ou `production` — ne se
renomme, ne se supprime ni ne se modifie : **on en écrit une nouvelle**. Seule
exception, une réécriture NÉCESSAIRE, et déclarée (plus bas).

Prisma reconnaît une migration au **nom de son dossier**
(`apps/api/prisma/migrations/<horodatage>_<nom>/`) et note chaque nom appliqué
dans la table `_prisma_migrations` de la base. Ce qui arrive sinon, mesuré :

| Geste | Sur un serveur qui l'a déjà appliquée |
| --- | --- |
| **Renommer** le dossier | la base la prend pour une nouvelle, la rejoue et échoue (`already exists`, P3018) ; puis Prisma refuse **toute** migration suivante (P3009) — chaque déploiement s'arrête à l'étape 4/8 |
| **Modifier** son `migration.sql` | `migrate deploy` passe **sans un mot** : la base garde l'ancienne version, un serveur neuf reçoit la nouvelle, et plus rien ne dit laquelle tourne où |
| **Supprimer** le dossier | la base garde un schéma que plus aucun fichier ne décrit ; un serveur neuf ne l'aura jamais |

La garde : `scripts/ci/migrations_publiees.sh` compare les `migration.sql` d'un
commit déjà poussé à ceux d'aujourd'hui. Les ajouts passent ;
`migration_lock.toml` n'est pas regardé. Elle tourne :

- dans **api-ci**, en poussée, contre le **dernier commit dont api-ci a été
  vert** sur la branche — pas le commit d'avant la poussée : une réécriture
  (rouge) suivie d'une poussée sans rapport aurait comparé la seconde à la
  première, serait passée au vert, et ses images seraient parties en recette.
  En pull request, contre la branche cible ;
- en tête de **`./scripts/check.sh`**, contre la base commune avec
  `origin/development`.

Ses essais : `scripts/ci/tests/migrations_publiees_test.sh`, rejoués par
`./scripts/check_infra.sh` et infra-ci.

## Réécriture nécessaire

**Une migration échoue sur une base VIERGE.** api-ci est rouge dès sa poussée
(les e2e rejouent `migrate deploy` sur une base vide) : ce commit n'a donc pas
d'images, et la migration n'a tourné sur aucun serveur. La corriger en place,
sans rien déclarer : la garde compare au dernier vert, où elle n'existait pas
encore.

**Une migration échoue sur un SERVEUR** (P3018, par exemple une contrainte que
les données existantes violent) alors qu'api-ci l'a passée. Prisma refuse
toute suite (P3009) tant qu'elle n'est pas résolue. Déjà passée sur un autre
serveur, elle ne se réécrit pas : corriger les DONNÉES du serveur en échec,
puis étapes 3 et 4 sans rien publier, avec le même sha. Sinon :

1. corriger son `migration.sql` en place, pour qu'il passe sur ces données et
   tolère ce que l'échec a pu laisser (`IF NOT EXISTS`, `DO $$ … $$`) ;
2. déclarer la réécriture : ajouter à `apps/api/prisma/migrations/REECRITES`
   la ligne `<dossier> <raison>`. La garde n'admet qu'une ligne AJOUTÉE depuis
   sa base : une fois publiée, elle ne couvre plus rien ;
3. publier, puis sur le serveur (`dc` : étape 1 de la section suivante) :
   `dc run --rm --entrypoint ./node_modules/.bin/prisma migrate migrate resolve --rolled-back <dossier>` ;
4. `carlysctl deploy <env> <nouveau sha>`.

## Pourquoi : le 19 septembre 2026

La migration `20260919193331_defis_entre_amis` a été publiée et appliquée en
recette, puis renommée `20260919201000_defis_entre_amis` (commit `9c633b2`,
contenu identique). La recette l'a rejouée : « type FriendChallengeStatus
already exists », migration en échec, et **tous les déploiements suivants se
sont arrêtés à l'étape migration pendant 8 jours**. Le renommage corrigeait
une migration cassée sur base vierge (elle référençait `ChallengeMetric`, créé
par une migration à l'horodatage postérieur) ; il n'a fait tomber la recette
que parce que le commit rouge d'avant avait eu ses images, ce que
`scripts/ci/verdict_ci.sh` refuse désormais.

## Réparer un serveur tombé dans ce cas

**À n'appliquer que si le dossier a été renommé SANS changer son contenu.**
Pour le vérifier, sur le serveur :

```bash
cd /srv/carlys/repo
git log --summary --format='%h %s' -- apps/api/prisma/migrations | grep -B3 ' => '
```

Chaque ligne `rename …/{ANCIEN => NOUVEAU}/migration.sql (100%)` est un
renommage pur : `100%` veut dire contenu identique. Sans `100%`, **arrête-toi**
et demande de l'aide : ce n'est plus la même réparation.

Le message du déploiement, lui, dit `P3009` et nomme la migration en échec :
c'est NOUVEAU. Dans les commandes ci-dessous, remplace ANCIEN et NOUVEAU par
les noms réels (le 19/09 : ANCIEN = `20260919193331_defis_entre_amis`,
NOUVEAU = `20260919201000_defis_entre_amis`).

**1. Préparer** — l'environnement, et le sha du déploiement qui échoue (celui
du message « DÉPLOIEMENT INTERROMPU ») :

```bash
cd /srv/carlys/repo
ENV=staging          # ou production
SHA=8c6205fe2453     # le sha du message d'erreur
dc() { CARLYS_TAG="sha-$SHA" docker compose -p "carlys_$ENV" \
  --env-file "/srv/carlys/$ENV/.env" -f infrastructure/server/compose.yml "$@"; }
```

**2. Sauvegarder la base** — on va toucher à l'historique des migrations :

```bash
carlysctl backup
```

**3. Déclarer NOUVEAU comme déjà appliquée** — c'est vrai : son contenu est
en base sous l'ancien nom.

```bash
dc run --rm --entrypoint ./node_modules/.bin/prisma migrate \
  migrate resolve --applied NOUVEAU
```

**4. Effacer la ligne d'ANCIEN** — un nom qui n'existe plus dans le code.
Ouvre la base :

```bash
dc exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

puis tape, en gardant les guillemets :

```sql
DELETE FROM "_prisma_migrations" WHERE migration_name = 'ANCIEN';
\q
```

La base doit répondre `DELETE 1`. Autre chose (`DELETE 0`) : le nom est mal
recopié — relis-le avant de continuer.

**5. Relancer le déploiement** — un sha qui a échoué n'est jamais retenté
tout seul :

```bash
carlysctl deploy "$ENV" "$SHA"
```

L'étape 4/8 doit finir sur « schéma à jour ».

Cette procédure a été rejouée le 28/09 sur une base jetable : historique de
la recette au 19/09, déploiement de `9c633b2` (P3018 puis P3009), étapes 3 et
4, puis toutes les migrations d'aujourd'hui appliquées sans erreur.
