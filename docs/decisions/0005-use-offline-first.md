# ADR 0005 — Architecture offline-first pour le mobile

## Statut

Acceptée — 2026-08

## Contexte

Le moment critique de Carlys est la **séance en salle de sport** : sous-sols,
zones blanches, Wi-Fi saturé — le réseau y est indisponible ou dégradé de façon
routinière. Un utilisateur qui enchaîne les séries doit pouvoir enregistrer
chaque répétition instantanément, sans spinner ni erreur réseau. Une app fitness
qui perd une séance ou bloque l'enregistrement faute de connexion perd la
confiance de l'utilisateur immédiatement. Le réseau doit donc être traité comme
une optimisation, pas comme un prérequis.

## Décision

L'application mobile est **offline-first** : la base locale **Drift/SQLite**
(ADR 0008) est la source de vérité de l'interface. Toute écriture est d'abord
locale, puis rejouée vers l'API via une **file d'opérations de synchronisation
idempotentes**, identifiées par des **UUID générés côté client** (paquet `uuid`).
La connectivité (`connectivity_plus`) déclenche la synchronisation ; elle ne
conditionne jamais l'usage.

## Raisons

- **Fiabilité perçue** : lecture et écriture locales = latence nulle et zéro
  échec pendant la séance, quel que soit l'état du réseau.
- **Idempotence par conception** : chaque entité créée localement porte un UUID
  définitif ; rejouer une opération après une coupure ne crée jamais de doublon
  côté serveur (upsert par UUID, transactions PostgreSQL — ADR 0003).
- **File d'opérations** plutôt que synchronisation d'état : l'ordre des
  mutations est préservé, chaque opération est petite, rejouable et traçable.
- Alternatives écartées :
  - **Online-only avec cache** : simple, mais échoue exactement là où l'app doit
    exceller (la salle de sport) ; un cache en lecture ne protège pas les
    écritures.
  - **Solutions de sync clé en main** (backend synchronisé propriétaire) :
    verrouillage fournisseur et perte de contrôle sur le modèle de données,
    incompatibles avec notre API NestJS/PostgreSQL et nos entitlements serveur
    (ADR 0006).

## Avantages

- L'app est pleinement utilisable en avion, en sous-sol, à l'étranger.
- Les identifiants locaux définitifs (UUID) suppriment toute phase de
  « réconciliation d'IDs » entre client et serveur.
- La file de synchronisation est testable unitairement (rejeu, conflits, ordre)
  sans réseau ni serveur.
- Le serveur reste l'autorité finale : validation, entitlements et agrégations
  de progression s'appliquent à la réception des opérations.

## Inconvénients

- **Coût assumé** : la synchronisation est un sous-système à part entière —
  file persistante, reprises avec backoff, gestion des erreurs définitives
  (opération rejetée par le serveur), télémetrie de sync. C'est le prix accepté
  de cette décision.
- Résolution de conflits à concevoir explicitement (même compte sur deux
  appareils) ; le modèle retenu est documenté dans
  `docs/synchronization/offline-first.md`.
- L'interface doit représenter des états intermédiaires (« enregistré sur
  l'appareil, en attente de synchronisation »), ce qui complexifie l'UX.
- Le schéma local Drift et le schéma serveur Prisma évoluent en parallèle :
  chaque tranche verticale doit livrer les deux migrations de façon cohérente.

## Conséquences

- L'Étape 4 (séances) livrera la première implémentation complète : tables
  Drift, file de synchronisation idempotente, endpoints d'ingestion côté API.
- Toute nouvelle fonctionnalité mobile est conçue « local d'abord » : on écrit
  dans Drift, la sync suit — jamais d'appel réseau bloquant sur le chemin
  critique d'une séance.
- Les entités synchronisables ont un UUID généré à la création locale et des
  horodatages permettant l'ordonnancement des opérations.
- Les endpoints d'ingestion de l'API doivent être idempotents et
  transactionnels : recevoir deux fois la même opération produit le même état.
