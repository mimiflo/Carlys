# ADR 0004 — Monolithe modulaire plutôt que microservices

## Statut

Acceptée — 2026-08

## Contexte

Carlys démarre avec une petite équipe et un produit livré en tranches verticales
(auth, exercices, séances, progression, abonnements, administration). La
tentation « microservices dès le départ » existe, mais elle impose un coût
opérationnel massif : réseau inter-services, déploiements multiples, traçage
distribué, cohérence des données entre bases, versionnage des contrats internes.
À ce stade, les frontières de domaine ne sont pas encore stabilisées — les
découper en services réseau serait figer des frontières qu'on découvre encore.

## Décision

L'API est un **monolithe modulaire** : un seul déploiement NestJS (`apps/api`),
une seule base PostgreSQL, mais un découpage interne strict en **modules par
domaine** (health, auth, exercises, workouts, progress, billing, admin…), chacun
avec ses contrôleurs, services et tests, et des frontières explicites entre eux.

## Raisons

- **Coût opérationnel minimal** : un artefact à builder (Dockerfile multi-stage),
  un service à déployer, superviser et faire évoluer — pas d'orchestration
  distribuée pour une équipe réduite.
- **Transactions simples** : une séance et ses séries, un webhook Stripe et la
  mise à jour des entitlements — tout tient dans une transaction PostgreSQL
  locale, sans saga ni compensation.
- **Frontières logiques d'abord** : les modules NestJS avec DI donnent la
  modularité (couplage faible, testabilité) sans payer le prix du réseau.
- **Réversibilité** : un module aux frontières nettes (pas d'accès aux tables
  des autres domaines, communication par interfaces de service) est extractible
  en service indépendant plus tard, si — et seulement si — une contrainte réelle
  l'exige (charge, équipe, isolation).
- Alternative écartée : **microservices dès le départ** — complexité
  (observabilité distribuée, latence réseau, cohérence éventuelle, duplication
  d'infra) sans aucun bénéfice à notre échelle actuelle.

## Avantages

- Vélocité : une tranche verticale = un module + ses migrations + ses tests,
  livrés dans une seule PR et un seul déploiement.
- Débogage simple : une stack trace unique, des logs corrélés par `requestId`
  dans un seul processus, un seul `/metrics` Prometheus.
- Environnement de dev complet en un `docker compose up -d`.
- Refactoring inter-domaines trivial tant que tout vit dans le même dépôt et le
  même processus.

## Inconvénients

- **La discipline remplace la contrainte technique** : rien n'empêche
  physiquement un module d'importer les entrailles d'un autre — les revues de
  code et les conventions doivent tenir la frontière.
- Scalabilité uniforme : on ne peut pas dimensionner un domaine indépendamment ;
  tout le monolithe scale horizontalement d'un bloc (il doit donc rester
  stateless, état partagé dans PostgreSQL/Redis).
- Un bug grave (fuite mémoire, boucle) peut dégrader tous les domaines à la fois.
- Le build et la suite de tests s'allongent avec chaque module ajouté.

## Conséquences

- Règles de frontière : un module n'accède jamais directement aux tables d'un
  autre domaine ; les échanges passent par les services exportés du module
  concerné. Les traitements asynchrones passeront par BullMQ (Redis) plutôt que
  par un bus inter-services.
- L'API reste sans état : sessions et caches dans Redis, données dans
  PostgreSQL — la montée en charge se fait par réplication du conteneur.
- Toute proposition d'extraction en microservice devra faire l'objet d'un
  nouvel ADR, motivé par une contrainte mesurée et non par principe.
- Le versioning URI (`/api/v1`) et les enveloppes de réponse communes
  (`packages/api-contracts`) valent pour tous les modules, garantissant un
  contrat homogène malgré la croissance interne.
