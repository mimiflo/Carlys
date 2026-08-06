# ADR 0008 — Drift (SQLite) pour la persistance locale mobile

## Statut

Acceptée — 2026-08

## Contexte

L'architecture offline-first (ADR 0005) fait de la base locale la source de
vérité de l'interface mobile. Les données à stocker sont relationnelles (séances
→ séries → exercices, miroir du schéma serveur — ADR 0003) et doivent être
requêtées finement : historique filtré, agrégations de progression, file
d'opérations de synchronisation ordonnée. Il faut des requêtes réactives (l'UI
d'une séance en cours se met à jour à chaque série enregistrée), des
transactions locales et des **migrations de schéma versionnées**, car la base
vivra sur les appareils des utilisateurs à travers toutes les mises à jour de
l'app.

## Décision

La persistance locale de l'application Flutter repose sur **Drift**
(`drift` + `drift_dev` + `sqlite3_flutter_libs`), une couche typée et réactive
au-dessus de **SQLite**.

## Raisons

- **SQL typé, vérifié à la compilation** : tables déclarées en Dart, requêtes
  composables dont les résultats sont des classes générées — pas de `Map`
  anonymes ni de colonnes fantômes comme avec sqflite brut.
- **Réactivité native** : toute requête peut être exposée en `Stream` qui
  ré-émet à chaque écriture concernée — branchement direct sur les providers
  Riverpod (ADR 0007).
- **Migrations intégrées** : `schemaVersion`, `MigrationStrategy` et outillage
  de test des migrations — indispensable pour faire évoluer la base sur le
  terrain sans perte de données.
- **C'est du SQLite** : moteur relationnel éprouvé, transactions ACID locales,
  index, jointures — le modèle local peut refléter le modèle serveur PostgreSQL
  et la file de synchronisation est une simple table ordonnée.
- Alternatives écartées :
  - **Hive** : clé-valeur rapide mais sans relations, sans requêtes riches et
    avec des migrations manuelles — inadapté à séances/séries et à une file de
    sync requêtable.
  - **Isar** : requêtes riches et réactives, mais moteur NoSQL propriétaire
    dont la maintenance a connu des périodes d'incertitude ; pour des données
    aussi relationnelles, SQLite reste le choix le plus sûr et le plus durable.
  - **sqflite brut** : accès SQLite direct mais tout en chaînes de caractères —
    aucune vérification de type, mapping manuel, pas de réactivité ; coût
    d'erreur élevé sur un schéma qui évoluera à chaque étape.

## Avantages

- Modèle mental unique : du SQL côté serveur (PostgreSQL/Prisma) et côté client
  (SQLite/Drift), avec des schémas volontairement proches.
- Agrégations locales performantes (records, volumes, progression) sans appel
  réseau.
- Transactions locales : une séance et ses séries s'écrivent atomiquement, même
  logique que côté serveur.
- Base de données en mémoire (`NativeDatabase.memory()`) pour des tests rapides
  et déterministes de la couche `data` et de la file de synchronisation.

## Inconvénients

- **Encore de la génération de code** : Drift s'ajoute à Riverpod, Freezed et
  json_serializable dans le même `build_runner` — builds plus longs, fichiers
  générés volumineux.
- Verbosité de la déclaration des tables et des DAO par rapport à un simple
  stockage clé-valeur — surdimensionné pour des préférences simples (qui
  peuvent rester dans `flutter_secure_storage` ou équivalent).
- Chaque évolution du schéma local exige une migration écrite et testée ; une
  migration ratée corrompt des données utilisateur sur le terrain.
- Deux schémas à maintenir en cohérence (Drift local, Prisma serveur) à chaque
  tranche verticale.

## Conséquences

- Les premières tables Drift arrivent avec l'Étape 4 (séances) : entités
  synchronisables avec UUID locaux, et table de file d'opérations de
  synchronisation idempotentes.
- La couche `data` de chaque feature encapsule ses DAO Drift ; `domain` et
  `presentation` ne voient que des repositories exposés via Riverpod.
- Toute évolution du schéma local incrémente `schemaVersion` avec sa migration
  testée, livrée dans la même PR que la fonctionnalité.
- Les données sensibles (tokens) ne vont pas dans Drift : elles restent dans
  `flutter_secure_storage`.
