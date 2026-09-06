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
| Exercices | **Livré** — `GET /api/v1/exercises` (recherche `search`, filtres `muscleGroup`/`equipment`/`difficulty`/`type`, pagination `cursor`+`limit`, `meta.nextCursor`/`hasMore`/`total`), `GET /api/v1/exercises/:idOrSlug`, `GET /api/v1/muscle-groups` (groupes NON VIDES seulement), `GET /api/v1/equipment` — catalogue seedé (170 exercices, dont 155 illustrés : pectoraux, biceps, dos, triceps, épaules et abdominaux), cache Redis tolérant aux pannes, exercices non publiés jamais servis | Étape 3 ✅ |
| Modèles de séance | **Livré** — `GET /api/v1/workout-templates` (curseur), `GET /workout-templates/:id`, `PUT /workout-templates/:id` (**unique écriture**, create-or-replace, 201/200), `DELETE /workout-templates/:id` (suppression logique rejouable) — voir le tableau détaillé ci-dessous. Programmes multi-semaines : voir la ligne dédiée | Étape 4 ✅ |
| Séances | **Livré** — `POST /workout-sessions` (création idempotente, id appareil, `templateId`/`templateName` facultatifs et jamais bloquants), `GET /workout-sessions` (curseur), `GET/PATCH /workout-sessions/:id`, `POST …/:id/complete` et `…/:id/abandon` (rejouables, 409 si clôture croisée) | Étape 4 ✅ |
| Séries | **Livré** — `POST /workout-sessions/:id/sets` (upsert idempotent, nom d'exercice résolu depuis le catalogue, `plannedReps`/`plannedWeightKg`/`planItemId` facultatifs), `PATCH /workout-sets/:id` (corrige le fait réalisé, jamais la cible), `DELETE /workout-sets/:id` (suppression logique rejouable) | Étape 4 ✅ |
| Progression | **Livré** — `GET /api/v1/progress/overview?period=week\|month\|year` (totaux + volume par intervalle), `GET /api/v1/progress/records` (records personnels), `GET /api/v1/progress/exercises/:exerciseId` (progression par séance), `GET/POST /api/v1/body-metrics` (création idempotente, id appareil), `DELETE /api/v1/body-metrics/:id` (suppression logique rejouable) | Étape 5 ✅ |
| Nutrition | **Livré** — `GET /api/v1/nutrition/metabolism` : rapport métabolique calculé **côté serveur** (BMR Mifflin-St Jeor, TDEE par niveau d'activité, objectif calorique selon le but, macros protéines/lipides/glucides, IMC + catégorie OMS, hydratation) ; le poids provient de la **dernière mesure corporelle**, le profil (sexe, naissance, taille, activité, objectif) se complète via `PATCH /users/me` ; profil incomplet → `metabolism: null` + liste `missing` | Post-Étape 7 ✅ |
| Abonnements | **Livré** — `GET /api/v1/subscriptions/me` (plan effectif + abonnement projeté), `GET /api/v1/entitlements` (droits évalués **côté serveur**, expiration réévaluée à chaque lecture) ; le catalogue applique `premium_exercises` (fiche premium → 403 sans droit) | Étape 6 ✅ |
| Webhooks paiement | **Livré** — `POST /api/v1/webhooks/stripe` (signature `Stripe-Signature` HMAC-SHA256 sur corps brut, tolérance anti-rejeu 5 min), `POST /api/v1/webhooks/revenuecat` (`Authorization: Bearer`) — **idempotents** (journal `SubscriptionEvent`, unicité `(provider, externalEventId)`), 503 tant que le secret n'est pas configuré, échec de traitement journalisé et retraitable | Étape 6 ✅ |
| Administration | **Livré** — `POST /api/v1/admin/auth/login` (comptes séparés, jeton à audience dédiée 12 h, 429 après `AUTH_MAX_LOGIN_ATTEMPTS` échecs : même verrouillage que le mobile, compteur distinct), `GET /admin/auth/me`, `GET /admin/overview`, `GET /admin/users` (recherche + curseur), `GET /admin/users/:id`, `PATCH /admin/users/:id/status` (suspension = sessions révoquées), `PUT /admin/users/:id/entitlements` (attribution manuelle auditée), `GET /admin/audit-logs`, `GET /admin/exercises` (catalogue **publiés ET non publiés**, recherche, curseur), `PATCH /admin/exercises/:id/publication` — RBAC par permission (`user:read`, `user:update`, `entitlement:grant`, `exercise:read`, `exercise:publish`, `exercise:write`, `media:read`, `media:write`, `audit:read`) ; catalogue : `DELETE /admin/exercises/:id` (suppression DOUCE) + `POST /admin/exercises/:id/restore`, `PATCH /admin/exercises/:id/categories`, CRUD `/admin/muscle-groups`, `GET /admin/equipment` | Étape 7 ✅ |
| Programmes | **Livré** — `GET /api/v1/programs` (curseur), `GET /programs/:id`, `PUT /programs/:id` (**unique écriture**, create-or-replace, 201/200), `DELETE /programs/:id` (suppression logique rejouable) — plafond du plan gratuit à la création (`unlimited_programs`), voir le tableau détaillé ci-dessous | Post-Étape 7 ✅ |
| Médias | **Livré** — `POST /api/v1/admin/media` (dépôt multipart rejouable), `GET /admin/media`, `DELETE /admin/media/:id`, `PUT /admin/exercises/:id/image`, `PUT /admin/exercises/:id/mesh` — voir le tableau détaillé ci-dessous | Post-Étape 7 ✅ |
| Coach IA | **Livré** — `GET /api/v1/coach/conversations`, `POST /coach/conversations` (identifiant fourni par l'appareil, rejouable), `GET /coach/conversations/:id`, `POST /coach/conversations/:id/messages` (identifiant de message fourni par l'appareil, rejouable dans SON fil : un message déjà répondu rend la même réponse, sans tour de quota ni appel au modèle ; même identifiant avec un autre contenu → 409 ; identifiant déjà porté par un autre fil ou fil d'autrui → 404 opaque, sans tour de quota), `POST /coach/proposals/:id/accepted` (204, n'écrit AUCUNE séance) — droit `ai_coaching` décidé côté serveur (403 sans lui), quota quotidien par utilisateur en Redis (429), voir `docs/product/coach-ia.md` | Post-Étape 7 ✅ |
| Communauté | **Livré** — `GET /community/feed`, `POST /community/encouragements` (201), `GET /community/friends`, `DELETE /community/friends/:userId` (204), `GET/POST /community/requests` (202 opaque, refus opposable 30 jours, seau dédié 10 demandes/min par adresse → 429), `POST /community/requests/:id/accept` et `…/decline` (204), `GET /community/challenges`, `POST` et `DELETE /community/challenges/:id/join`, `POST /community/quiz-answers` (204), `GET/PATCH /community/profile` (confidentialité) — voir `docs/product/community.md` | Post-Étape 7 ✅ |
| Repas | **Livré** — `POST /api/v1/nutrition/meals` (201, création idempotente par id appareil), `GET /nutrition/meals` (journal du jour), `DELETE /nutrition/meals/:id` (204) — alimente les kcal consommées de l'accueil | Post-Étape 7 ✅ |
| Notifications | **Livré** — `POST /api/v1/notifications/device-tokens` (204, enregistrement rejouable), `DELETE /notifications/device-tokens` (204, à la déconnexion), `GET /notifications/preferences` (toutes les familles ; jamais réglée = acceptée), `PATCH /notifications/preferences` (204, refus respecté À L'ENVOI côté serveur) ; l'envoi part via FCM, voir `docs/product/notifications.md` | Post-Étape 7 ✅ |

Les chemins exacts, les DTO et les réponses seront fixés à l'implémentation ;
le tableau engage le périmètre, pas la signature finale.

### Endpoints livrés — authentification (Étape 2)

Tous enveloppés (`{ data, meta, requestId }` / enveloppe d'erreur) et
authentifiés par le guard global sauf mention `public`. Les endpoints
sensibles à l'abus (`register`, `login`, `verify-email`, `forgot-password`,
`reset-password`) portent un throttle renforcé (10 requêtes / 60 s) en plus du
rate limiting global.

**Où mènent les liens des e-mails.** `register` et `resend-verification`
envoient un lien `${PUBLIC_APP_URL}/verify-email?token=…`, `forgot-password`
un lien `${PUBLIC_APP_URL}/reset-password?token=…`. Ces deux pages sont des
**pages web publiques** servies par l'application Next.js (`apps/admin`,
groupe de routes `src/app/(public)`, sans coquille d'administration) : la
première poste le jeton sur `POST /auth/verify-email` dès son ouverture, la
seconde affiche le formulaire de nouveau mot de passe et poste sur
`POST /auth/reset-password`. `PUBLIC_APP_URL` doit donc désigner l'URL
publique de cette application web (en local `http://localhost:3001`), jamais
celle de l'API. Voir [`docs/architecture/admin.md`](../architecture/admin.md).

| Endpoint | Statuts | Notes |
| --- | --- | --- |
| `POST /api/v1/auth/register` (public) | 201, 400, 409 | Ouvre une session ; envoie l'e-mail de vérification |
| `POST /api/v1/auth/login` (public) | 200, 401, 429 | 401 générique (anti-énumération) ; 429 en cas de verrouillage |
| `POST /api/v1/auth/refresh` (public) | 200, 401 | Rotation ; réutilisation détectée → session révoquée |
| `POST /api/v1/auth/logout` | 204, 401 | Révoque la session courante |
| `POST /api/v1/auth/verify-email` (public) | 204, 401 | Jeton à usage unique ; **consommateur : page web `/verify-email`** (aucun écran mobile) |
| `POST /api/v1/auth/resend-verification` | 204 | Sans effet si déjà vérifié ; **aucun appelant** au 3 septembre 2026 (ni mobile ni web) |
| `POST /api/v1/auth/forgot-password` (public) | 202 | Réponse identique que le compte existe ou non |
| `POST /api/v1/auth/reset-password` (public) | 204, 401 | Révoque **toutes** les sessions ; **consommateur : page web `/reset-password`** (aucun écran mobile) |
| `POST /api/v1/auth/change-password` | 204, 401 | Révoque les autres sessions ; **aucun appelant** au 3 septembre 2026 (ni mobile ni web) |
| `GET /api/v1/auth/sessions` | 200 | Appareils connectés (`current` sur la session appelante) |
| `DELETE /api/v1/auth/sessions/:id` | 204, 404 | Déconnexion d'un appareil |
| `DELETE /api/v1/auth/sessions` | 204 | Déconnexion de tous les autres appareils |
| `GET /api/v1/users/me` | 200, 401 | Profil de l'utilisateur connecté |
| `PATCH /api/v1/users/me` | 200, 400 | `displayName`, `locale`, `timezone` |
| `DELETE /api/v1/users/me` | 204, 401 | Mot de passe requis ; en une transaction : sessions supprimées avec leurs refresh tokens (adresse IP, user-agent et nom d'appareil partent avec le compte), compte `DELETED`, adresse et code ami réécrits en valeurs tombales, profil personnel effacé, jetons d'appareil supprimés. L'adresse redevient disponible pour une nouvelle inscription |

### Endpoints livrés — modèles de séance (Étape 4)

Un **modèle de séance** est un document *prescriptif* réutilisable (« ce qui
est prévu »), distinct de la séance *réalisée*. Contrat complet et décisions
argumentées : [`docs/product/workout-templates.md`](../product/workout-templates.md).

| Endpoint | Statuts | Notes |
| --- | --- | --- |
| `GET /api/v1/workout-templates` | 200, 401 | Mes modèles, `updatedAt DESC, id DESC`, pagination `cursor` + `limit` ; `meta.nextCursor`/`hasMore` |
| `GET /api/v1/workout-templates/:id` | 200, 401, 404 | Détail complet, exercices et séries prévues ordonnés. **404 dans les trois cas** : inconnu, supprimé, ou appartenant à autrui |
| `PUT /api/v1/workout-templates/:id` | 200, 201, 400, 401, 404, 409 | **Unique écriture** : le corps décrit l'état complet, le serveur y fait converger la base en une transaction. **201** à la création, **200** au remplacement |
| `DELETE /api/v1/workout-templates/:id` | 204, 401, 404 | Suppression **logique**, rejouable : modèle inconnu ou déjà supprimé → 204 ; modèle d'autrui → 404 |

Ce que le `PUT` garantit, et pourquoi le mobile peut le rejouer sans état :

- **Tous les identifiants viennent de l'appareil** (modèle, lignes d'exercice,
  séries prévues) et sont conservés tels quels : rejouer le même corps redonne
  exactement le même état, sans journal de clés d'idempotence côté serveur.
- **Les positions ne sont jamais transmises** : l'ordre des tableaux JSON fait
  foi, le serveur écrit `position = index`. Un client ne peut donc produire ni
  trou ni doublon de position.
- **Le nom d'exercice est résolu comme pour les séries** : si `exerciseId`
  désigne un exercice **publié**, son nom du catalogue gagne ; sinon la ligne
  devient un exercice libre porté par `exerciseName` trimé. Les deux absents →
  `400 VALIDATION_ERROR`.
- **Le contenu est remplacé physiquement** (lignes et séries prévues) dans la
  transaction : ce n'est pas de l'historique. `lastUsedAt` et `deletedAt` ne
  sont jamais touchés par un `PUT` — et un modèle supprimé ne ressuscite pas
  (404).
- Erreurs : `400` (bornes, `exercises` vide ou > 30, > 20 séries par exercice,
  identifiant dupliqué dans le corps), `404` (modèle supprimé logiquement),
  `409` (`:id` appartient à un autre compte).

Effets sur les endpoints de séance existants, **additifs et non cassants** :

| Route | Ajout | Règle |
| --- | --- | --- |
| `POST /workout-sessions` | `templateId`, `templateName` (facultatifs) | La création **n'échoue jamais** à cause du modèle : `templateId` inconnu, supprimé ou à autrui est ignoré (`templateId: null`) et le `templateName` du client est conservé. Sinon, le nom **serveur** est retenu et `lastUsedAt` est daté dans la même transaction |
| `POST /workout-sessions` | `plan[]` (facultatif, ≤ 600 entrées) | Le **plan copié du modèle au lancement**, écrit dans la transaction de création : un rejeu l'annule avec elle, donc jamais de doublon. Un `exerciseId` inconnu dégrade la prévision en exercice libre (`exerciseId: null`, nom conservé) plutôt que de refuser la séance. Transmis à la création **seulement** — le plan est figé |
| `GET /workout-sessions/:id` | `plan[]` | Le plan stocké, trié par (exercice, série), avec `doneSetId` et `skipped`. C'est ce qui permet de reprendre la séance sur un autre appareil avec ses cibles |
| `POST /workout-sessions/:id/sets` | `plannedReps`, `plannedWeightKg` (facultatifs) | La cible **affichée** au moment de la validation. La déviation est normale : une série faite à 7 reps pour 8 prévues s'enregistre sans erreur |
| `POST /workout-sessions/:id/sets` | `planItemId` (facultatif) | Apparie la série à la prévision qu'elle honore. Inconnu, déjà honoré ou d'une autre séance : **ignoré**, jamais bloquant — la série est le fait, l'appariement un confort d'affichage |
| `POST /workout-sessions/:id/plan/skip` | *(nouvelle route)* | Passe des prévisions (`planItemIds[]`). Idempotent, et sans effet sur celles déjà honorées par une série : un fait acquis ne se « saute » pas après coup. `404` si la séance appartient à autrui |
| `PATCH /workout-sets/:id` | — | **Ne les accepte pas** (400) : corriger une série corrige le fait réalisé, la cible affichée à l'instant de la validation n'est pas réécrivable |

Journalisation : un log Pino `info` par écriture (`workout_template.saved`,
`workout_template.deleted`) avec `templateId`, `exercisesCount`,
`plannedSetsCount`, corrélé au `requestId` — **jamais** le contenu des notes.
Pas d'entrée `AuditLog` : ce journal est réservé aux événements de sécurité et
aux actions d'administration.

### Endpoints livrés — programmes multi-semaines

Un programme dit **quand** s'entraîner ; le modèle de séance dit **quoi**
faire. Le programme ne duplique donc aucun exercice : chaque jour renvoie à un
modèle existant, ou n'annonce qu'un intitulé (repos, activité libre).

| Endpoint | Statuts | Notes |
| --- | --- | --- |
| `GET /api/v1/programs` | 200, 401 | Mes programmes, `updatedAt DESC`, pagination `cursor` + `limit` |
| `GET /api/v1/programs/:id` | 200, 401, 404 | Jours triés (semaine, puis jour). **404 dans les trois cas** : inconnu, supprimé, ou à autrui |
| `PUT /api/v1/programs/:id` | 200, 201, 400, 401, 403, 404, 409 | **Unique écriture** : le corps décrit l'état complet. **201** à la création, **200** au remplacement |
| `DELETE /api/v1/programs/:id` | 204, 401, 404 | Suppression **logique**, rejouable ; programme d'autrui → 404 |

Ce que le `PUT` garantit :

- **Les identifiants viennent de l'appareil** (programme et jours) : rejouer le
  même corps redonne exactement le même état, sans journal d'idempotence — et
  un programme se crée hors ligne.
- **Le contenu est remplacé physiquement** dans la transaction. Un programme
  supprimé ne ressuscite pas (404).
- **Un seul programme actif** par compte : activer le suivant désactive le
  précédent dans la MÊME transaction, sinon deux plans « en cours »
  coexisteraient le temps d'un aller-retour.
- **Un modèle inconnu, supprimé ou appartenant à autrui ne fait pas échouer
  l'enregistrement** : la case garde son intitulé et perd son lien. Le plan
  reste lisible, ce qui compte plus que le lien.
- Erreurs : `400` (semaine hors du plan, deux entrées sur la même case — refusé
  ici pour donner un message lisible plutôt qu'un 500 de PostgreSQL), `403`
  (plafond du plan gratuit), `409` (identifiant pris par un autre compte).

Le plafond du plan gratuit (`PROGRAM_FREE_LIMIT`) ne s'applique **qu'à la
création** : un compte redevenu gratuit garde ses programmes et peut les
modifier, il ne peut simplement plus en ajouter. C'est une **décision
serveur**, réévaluée à chaque écriture — le client ne fait jamais ce calcul.

### Endpoints livrés — médias (administration)

**Tout fichier servi par l'application entre par ici.** Photo d'exercice
aujourd'hui, maillage 3D demain : même dépôt, même stockage objet, même URL.
Rien n'est embarqué dans l'application, donc ajouter une illustration ne
demande aucune livraison. Décision et alternatives écartées :
[ADR 0009](../decisions/0009-use-object-storage-for-media.md).

Toutes ces routes exigent un **jeton d'administration** (audience dédiée) et la
permission indiquée.

| Endpoint | Permission | Statuts | Notes |
| --- | --- | --- | --- |
| `GET /api/v1/admin/exercises` | `exercise:read` | 200, 403 | Catalogue du back-office : **publiés ET non publiés**, recherche `search` sur nom/slug, pagination par curseur. Chaque ligne porte le média **entier** (nom du fichier, dimensions), pas seulement son URL |
| `POST /api/v1/admin/media` | `media:write` | 201, 400, 403, 413, 415 | `multipart/form-data` : `id` (**UUID fourni par l'admin**), `kind` (`IMAGE`/`MESH_3D`/`VIDEO`), `file`. **Rejouable** : le même `id` renvoie le média existant sans second dépôt |
| `GET /api/v1/admin/media` | `media:read` | 200, 403 | Bibliothèque, du plus récent au plus ancien, filtrable par `kind` |
| `DELETE /api/v1/admin/media/:id` | `media:write` | 204, 400, 403, 404 | Suppression **logique** ; **400 tant qu'un exercice référence le média** |
| `PUT /api/v1/admin/exercises/:id/image` | `exercise:write` | 204, 400, 403, 404 | `{ "mediaId": "<uuid>" }` — `null` détache |
| `PUT /api/v1/admin/exercises/:id/mesh` | `exercise:write` | 204, 400, 403, 404 | Idem pour le maillage 3D |

Ce que ces routes garantissent :

- **L'identifiant vient de l'administration**, et c'est lui qui fait la clé de
  stockage (`image/<uuid>.webp`) — jamais le nom du fichier déposé. Un envoi
  relancé après une coupure réseau ne crée donc ni doublon en base ni second
  objet.
- **Le genre et le type MIME doivent concorder** : un `model/gltf-binary`
  annoncé `IMAGE` est refusé en `415`, et un média `MESH_3D` ne peut pas être
  rattaché comme photo (`400`). Une fiche cassée ne s'installe pas par erreur.
- **Deux plafonds** : `MEDIA_MAX_UPLOAD_BYTES` (métier, configurable, `413`) et
  un plafond de transport coupé pendant la réception.
- **Le rattachement invalide le cache du catalogue** : la photo apparaît à la
  requête suivante, pas une heure plus tard.
- **Toutes ces actions sont auditées** (`admin.media_uploaded`,
  `admin.media_deleted`, `admin.exercise_media_attached`,
  `admin.exercise_media_detached`).

Côté mobile, le catalogue expose l'URL publique et **jamais** la clé de
stockage : `imageUrl` sur `ExerciseSummary` (donc aussi sur le détail),
`meshUrl` sur `ExerciseDetail`. Les deux valent `null` tant qu'aucun média
n'est rattaché — l'écran retombe alors sur son repli.

`imageUrl` est **consommé** par l'application (vignette de la carte et en-tête
de la fiche), avec cache disque et repli hors ligne — voir
[`docs/architecture/mobile.md`](../architecture/mobile.md). `meshUrl` est servi
mais pas encore affiché : rien ne rend de maillage 3D aujourd'hui.

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
