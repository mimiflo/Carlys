# ADR 0003 — PostgreSQL comme base de données principale

## Statut

Acceptée — 2026-08

## Contexte

Le cœur métier de Carlys est profondément **relationnel** : un utilisateur a des
séances, une séance contient des séries, une série référence un exercice, un
exercice appartient à des groupes musculaires et du matériel ; la progression et
les records se calculent par agrégation sur cet historique. Les écritures
doivent être transactionnelles (une séance synchronisée arrive avec toutes ses
séries ou pas du tout — voir ADR 0005), les lectures doivent rester rapides sur
de gros historiques, et les e-mails doivent être uniques sans sensibilité à la
casse. Il faut aussi une base gérable en local (Docker) comme en production
(service managé).

## Décision

**PostgreSQL 17** est la base de données principale, accédée exclusivement via
**Prisma 6** depuis l'API. Le schéma est normalisé ; le JSON (`jsonb`) est
réservé aux payloads externes (webhooks Stripe/RevenueCat, métadonnées
d'intégrations), jamais aux données métier requêtées.

## Raisons

- **Modèle relationnel normalisé** : les relations séances/séries/exercices avec
  contraintes d'intégrité (clés étrangères, unicité, `NOT NULL`) sont exactement
  ce que PostgreSQL garantit nativement — pas de cohérence à réimplémenter en
  application.
- **Transactions ACID** : indispensable pour la synchronisation idempotente des
  séances (Étape 4) et les webhooks d'abonnement (Étape 6).
- **Index riches** : index composites et partiels pour les requêtes d'historique
  et de progression, sans dénormalisation prématurée.
- **`citext`** : e-mails insensibles à la casse au niveau du type de colonne
  (extension activée dès `infrastructure/database/init/01-init.sql`, y compris
  pour la base `carlys_test`).
- Alternatives écartées :
  - **MongoDB** : le schéma flexible n'apporte rien à un domaine aussi
    structuré ; jointures et transactions multi-documents y sont plus coûteuses
    et les garanties d'intégrité reposeraient sur le code applicatif.
  - **MySQL/MariaDB** : viable, mais inférieur pour notre usage — pas de
    `citext`, index partiels absents, `jsonb` et fonctionnalités SQL avancées
    moins abouties, écosystème Prisma/Postgres mieux éprouvé.

## Avantages

- Intégrité garantie par la base : impossible d'avoir une série orpheline ou
  deux comptes avec le même e-mail à la casse près.
- Un seul moteur pour tout : données métier, agrégations de progression, payloads
  externes en `jsonb` — pas de seconde base à opérer.
- Écosystème managé mature (sauvegardes, réplication, PITR) pour le passage en
  production sans changement de code.
- `gen_random_uuid()` natif : cohérent avec les UUID générés côté mobile
  (ADR 0005).

## Inconvénients

- Les migrations de schéma deviennent un acte d'exploitation : elles s'exécutent
  via `prisma migrate deploy` **avant** la bascule du trafic, jamais au boot du
  conteneur — cela impose de la discipline de déploiement.
- Les évolutions de modèle demandent plus de rigueur qu'en schéma flexible
  (chaque changement = une migration versionnée).
- La scalabilité horizontale en écriture est limitée (un primaire) ; largement
  suffisant à notre échelle, mais à garder en tête.
- Prisma ajoute sa propre couche (client généré, moteur) entre le code et SQL.

## Conséquences

- Le schéma Prisma (`apps/api/prisma/schema.prisma`) est volontairement vide de
  modèles à l'Étape 1 ; les modèles arrivent par tranches verticales (Étape 2 :
  User/UserSession… ; Étape 3 : Exercise… ; Étape 4 : WorkoutSession/WorkoutSet…),
  le modèle cible étant documenté dans `docs/database/schema.md`.
- En développement, PostgreSQL tourne via `docker-compose.yml` (`postgres:17-alpine`) ;
  en production, service managé.
- La CI valide le schéma (`prisma validate`) et détecte les migrations manquantes
  à chaque PR.
- Toute donnée requêtée par le métier doit être une colonne typée — le `jsonb`
  qui commence à être filtré ou joint doit être promu en colonnes.
