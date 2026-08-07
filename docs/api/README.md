# Conventions d'API

Ce document définit les conventions HTTP de l'API Carlys : versioning,
enveloppes de réponse, codes d'erreur, corrélation des requêtes, pagination,
endpoints techniques et endpoints cibles du MVP. Les schémas Zod des
enveloppes vivent dans `packages/api-contracts` et sont partagés entre l'API
et les clients TypeScript.

Architecture de l'API : [`docs/architecture/backend.md`](../architecture/backend.md).

## URL de base et versioning

Toutes les routes métier sont versionnées par URI sous le préfixe :

```text
/api/v1
```

Préfixe (`api`) et version (`1`) sont des constantes de
`@carlys/shared-config` (`API_GLOBAL_PREFIX`, `API_VERSION`). Une rupture de
contrat entraînera un `/api/v2` — jamais de rupture silencieuse dans `v1`.

Les endpoints techniques (`/health`, `/health/live`, `/health/ready`,
`/metrics`) sont volontairement **hors** préfixe et **hors** enveloppe : ils
s'adressent aux orchestrateurs et à la supervision, pas aux clients métier.

## En-tête `x-request-id`

Chaque requête est corrélée par un identifiant :

- si le client envoie un en-tête `x-request-id` valide (1 à 64 caractères
  parmi `[A-Za-z0-9_-]`), il est repris tel quel ;
- sinon, l'API génère un UUID.

L'identifiant est systématiquement **renvoyé dans l'en-tête de réponse**
`x-request-id`, inclus dans chaque enveloppe (`requestId`) et présent dans
chaque ligne de log. C'est la clé à fournir dans tout signalement de bug.

## Enveloppe de succès

Toute réponse de succès d'une route `/api/v1/…` a exactement cette forme :

```json
{
  "data": {
    "id": "e5b6…",
    "name": "Développé couché"
  },
  "meta": {},
  "requestId": "6f1cbb3e-6c1e-4b6e-9e2d-b7f3a1c0d942"
}
```

- `data` — la charge utile (objet, tableau ou `null`) ;
- `meta` — métadonnées de la réponse (`{}` si aucune ; pagination le cas
  échéant, voir plus bas) ;
- `requestId` — l'identifiant de corrélation de la requête.

L'enveloppement est appliqué globalement par un intercepteur : les
contrôleurs retournent leurs données brutes, l'API garantit le format.

## Enveloppe d'erreur

Toute erreur a exactement cette forme :

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Exercice introuvable.",
    "details": [],
    "requestId": "6f1cbb3e-6c1e-4b6e-9e2d-b7f3a1c0d942"
  }
}
```

Une erreur de validation (DTO rejeté par `class-validator` — champs inconnus
refusés, contraintes non respectées) détaille chaque problème :

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Certaines données sont invalides.",
    "details": [
      { "message": "email must be an email" },
      { "message": "property isAdmin should not exist" }
    ],
    "requestId": "6f1cbb3e-6c1e-4b6e-9e2d-b7f3a1c0d942"
  }
}
```

Chaque entrée de `details` est de la forme `{ field?, message }`.

### Codes d'erreur

Le champ `code` est un enum fermé (`apiErrorCodeSchema` dans
`packages/api-contracts`) :

| Code | Statut HTTP | Signification |
| --- | --- | --- |
| `BAD_REQUEST` | 400 | Requête malformée (hors validation de DTO). |
| `VALIDATION_ERROR` | 400 | DTO invalide ; `details` liste les problèmes. |
| `UNAUTHORIZED` | 401 | Authentification absente ou invalide. |
| `FORBIDDEN` | 403 | Authentifié mais non autorisé. |
| `NOT_FOUND` | 404 | Ressource inexistante. |
| `CONFLICT` | 409 | Conflit d'état (doublon, version obsolète…). |
| `PAYLOAD_TOO_LARGE` | 413 | Corps > 1 Mo (`MAX_JSON_BODY_SIZE`). |
| `RATE_LIMITED` | 429 | Limite de débit dépassée (100 req / 60 s par défaut). |
| `INTERNAL_ERROR` | 500 | Erreur interne. Message générique : aucun détail technique ne fuite au client ; tout est dans les logs, corrélé par `requestId`. |
| `SERVICE_UNAVAILABLE` | 503 | Dépendance critique indisponible. |

## Pagination par curseur

Convention posée à l'Étape 1, appliquée à partir des premières listes
(Étape 3 — exercices). Jamais de pagination par offset.

Requête :

| Paramètre | Rôle | Valeur |
| --- | --- | --- |
| `limit` | taille de page | défaut `20`, maximum `100` (`DEFAULT_PAGE_SIZE` / `MAX_PAGE_SIZE`) |
| `cursor` | curseur opaque retourné par la page précédente | absent pour la première page |

Réponse — la pagination vit dans `meta` (`cursorPaginationMetaSchema`) :

```json
{
  "data": [
    { "id": "ex_01", "name": "Squat" },
    { "id": "ex_02", "name": "Soulevé de terre" }
  ],
  "meta": {
    "nextCursor": "eyJpZCI6ImV4XzAyIn0",
    "hasMore": true
  },
  "requestId": "6f1cbb3e-6c1e-4b6e-9e2d-b7f3a1c0d942"
}
```

- `nextCursor` — curseur opaque à renvoyer pour la page suivante, `null` sur
  la dernière page ;
- `hasMore` — `true` s'il reste des éléments.

Le curseur est **opaque** : les clients ne doivent ni le décoder ni le
construire.

## Endpoints techniques (Étape 1 — en place)

| Endpoint | Méthode | Description |
| --- | --- | --- |
| `/health` | GET | État complet : `status`, `uptimeSeconds`, composants `database` et `redis` avec latence. `200` si tout est `up`, `503` sinon. |
| `/health/live` | GET | Liveness : le processus répond. Toujours `200`, sans dépendance externe (le test e2e passe sans infrastructure). |
| `/health/ready` | GET | Readiness : PostgreSQL + Redis joignables. `200` ou `503`. Pilote la bascule de trafic au déploiement. |
| `/metrics` | GET | Métriques Prometheus (prom-client). Libre hors production ; en production, exige `Authorization: Bearer <METRICS_TOKEN>` (`401` sinon) et répond `404` si le token n'est pas configuré. |
| `/api/docs` | GET | Swagger UI. Activé partout **sauf en production** (surchargeable par `SWAGGER_ENABLED`). |

Exemple de réponse `/health` :

```json
{
  "status": "ok",
  "timestamp": "2026-08-06T10:00:00.000Z",
  "uptimeSeconds": 128,
  "components": {
    "database": { "status": "up", "latencyMs": 3 },
    "redis": { "status": "up", "latencyMs": 1 }
  }
}
```

Ces endpoints ne sont ni enveloppés ni soumis au rate limiting, et ne sont
pas auto-journalisés.

## Endpoints cibles du MVP (spécification produit — non implémentés)

La liste ci-dessous est la **cible** issue de la spécification produit,
marquée par étape. Aucune de ces routes n'existe encore ; chacune arrivera
avec sa tranche verticale complète (schéma Prisma → API → clients → tests →
docs) et sera documentée précisément ici à sa livraison.

| Domaine | Routes cibles (indicatives) | Étape |
| --- | --- | --- |
| Authentification | **Livré** — voir le tableau détaillé ci-dessous | Étape 2 ✅ |
| Utilisateur courant | **Livré** — `GET/PATCH/DELETE /api/v1/users/me`, sessions | Étape 2 ✅ |
| Exercices | **Livré** — `GET /api/v1/exercises` (recherche `search`, filtres `muscleGroup`/`equipment`/`difficulty`/`type`, pagination `cursor`+`limit`, `meta.nextCursor`/`hasMore`), `GET /api/v1/exercises/:idOrSlug`, `GET /api/v1/muscle-groups`, `GET /api/v1/equipment` — catalogue seedé (33 exercices), cache Redis tolérant aux pannes, exercices non publiés jamais servis | Étape 3 ✅ |
| Programmes | `GET/POST /api/v1/programs`, modèles de séances (`workout-templates`) | Étape 4 |
| Séances | **Livré** — `POST /workout-sessions` (création idempotente, id appareil), `GET /workout-sessions` (curseur), `GET/PATCH /workout-sessions/:id`, `POST …/:id/complete` et `…/:id/abandon` (rejouables, 409 si clôture croisée) | Étape 4 ✅ |
| Séries | **Livré** — `POST /workout-sessions/:id/sets` (upsert idempotent, nom d'exercice résolu depuis le catalogue), `PATCH /workout-sets/:id`, `DELETE /workout-sets/:id` (suppression logique rejouable) | Étape 4 ✅ |
| Progression | **Livré** — `GET /api/v1/progress/overview?period=week\|month\|year` (totaux + volume par intervalle), `GET /api/v1/progress/records` (records personnels), `GET /api/v1/progress/exercises/:exerciseId` (progression par séance), `GET/POST /api/v1/body-metrics` (création idempotente, id appareil), `DELETE /api/v1/body-metrics/:id` (suppression logique rejouable) | Étape 5 ✅ |
| Nutrition | **Livré** — `GET /api/v1/nutrition/metabolism` : rapport métabolique calculé **côté serveur** (BMR Mifflin-St Jeor, TDEE par niveau d'activité, objectif calorique selon le but, macros protéines/lipides/glucides, IMC + catégorie OMS, hydratation) ; le poids provient de la **dernière mesure corporelle**, le profil (sexe, naissance, taille, activité, objectif) se complète via `PATCH /users/me` ; profil incomplet → `metabolism: null` + liste `missing` | Post-Étape 7 ✅ |
| Abonnements | **Livré** — `GET /api/v1/subscriptions/me` (plan effectif + abonnement projeté), `GET /api/v1/entitlements` (droits évalués **côté serveur**, expiration réévaluée à chaque lecture) ; le catalogue applique `premium_exercises` (fiche premium → 403 sans droit) | Étape 6 ✅ |
| Webhooks paiement | **Livré** — `POST /api/v1/webhooks/stripe` (signature `Stripe-Signature` HMAC-SHA256 sur corps brut, tolérance anti-rejeu 5 min), `POST /api/v1/webhooks/revenuecat` (`Authorization: Bearer`) — **idempotents** (journal `SubscriptionEvent`, unicité `(provider, externalEventId)`), 503 tant que le secret n'est pas configuré, échec de traitement journalisé et retraitable | Étape 6 ✅ |
| Administration | **Livré** — `POST /api/v1/admin/auth/login` (comptes séparés, jeton à audience dédiée 12 h), `GET /admin/auth/me`, `GET /admin/overview`, `GET /admin/users` (recherche + curseur), `GET /admin/users/:id`, `PATCH /admin/users/:id/status` (suspension = sessions révoquées), `PUT /admin/users/:id/entitlements` (attribution manuelle auditée), `GET /admin/audit-logs`, `PATCH /admin/exercises/:id/publication` — RBAC par permission (`user:read`, `user:update`, `entitlement:grant`, `exercise:publish`, `audit:read`) | Étape 7 ✅ |

Les chemins exacts, les DTO et les réponses seront fixés à l'implémentation ;
le tableau engage le périmètre, pas la signature finale.

### Endpoints livrés — authentification (Étape 2)

Tous enveloppés (`{ data, meta, requestId }` / enveloppe d'erreur) et
authentifiés par le guard global sauf mention `public`. Les endpoints
sensibles à l'abus (`register`, `login`, `verify-email`, `forgot-password`,
`reset-password`) portent un throttle renforcé (10 requêtes / 60 s) en plus du
rate limiting global.

| Endpoint | Statuts | Notes |
| --- | --- | --- |
| `POST /api/v1/auth/register` (public) | 201, 400, 409 | Ouvre une session ; envoie l'e-mail de vérification |
| `POST /api/v1/auth/login` (public) | 200, 401, 429 | 401 générique (anti-énumération) ; 429 en cas de verrouillage |
| `POST /api/v1/auth/refresh` (public) | 200, 401 | Rotation ; réutilisation détectée → session révoquée |
| `POST /api/v1/auth/logout` | 204, 401 | Révoque la session courante |
| `POST /api/v1/auth/verify-email` (public) | 204, 401 | Jeton à usage unique |
| `POST /api/v1/auth/resend-verification` | 204 | Sans effet si déjà vérifié |
| `POST /api/v1/auth/forgot-password` (public) | 202 | Réponse identique que le compte existe ou non |
| `POST /api/v1/auth/reset-password` (public) | 204, 401 | Révoque **toutes** les sessions |
| `POST /api/v1/auth/change-password` | 204, 401 | Révoque les autres sessions |
| `GET /api/v1/auth/sessions` | 200 | Appareils connectés (`current` sur la session appelante) |
| `DELETE /api/v1/auth/sessions/:id` | 204, 404 | Déconnexion d'un appareil |
| `DELETE /api/v1/auth/sessions` | 204 | Déconnexion de tous les autres appareils |
| `GET /api/v1/users/me` | 200, 401 | Profil de l'utilisateur connecté |
| `PATCH /api/v1/users/me` | 200, 400 | `displayName`, `locale`, `timezone` |
| `DELETE /api/v1/users/me` | 204, 401 | Mot de passe requis ; suppression logique + révocation totale |

## Swagger et client typé

- **Swagger / OpenAPI** : l'API expose sa documentation interactive sur
  `/api/docs` (`@nestjs/swagger`, schéma d'auth Bearer déjà déclaré pour
  l'Étape 2). Désactivée en production par défaut.
- **Contrats partagés (aujourd'hui)** : les clients TypeScript (admin)
  consomment directement les schémas Zod de `packages/api-contracts`
  (enveloppes, contrats `/health`) — mêmes types des deux côtés du réseau.
- **Client typé généré (cible)** : à mesure que les routes métier arrivent,
  un client TypeScript sera généré depuis le document OpenAPI produit par
  Swagger (export JSON en CI, puis génération type `openapi-typescript`),
  afin que l'admin — et tout futur consommateur — soit typé de bout en bout
  sans duplication manuelle des contrats.
