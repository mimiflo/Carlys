# Manifeste : qui appelle quoi

Chaque route livrée par l'API déclare ici son **consommateur**. Ce n'est pas
une commodité : `docs/api/README.md` a pu annoncer « Livré » des routes que
personne n'appelait, pendant des mois, sans qu'aucune vérification ne s'en
aperçoive — six d'un coup au moment de l'audit du 3 septembre 2026.

Une route sans client n'est pas forcément un défaut. C'est toujours une
**décision**, et une décision doit être écrite, motivée et datée.

## Comment ce fichier est tenu

`apps/api/test/route-clients.e2e-spec.ts` engendre le document OpenAPI — la
même source que `/api/docs`, produite comme dans `main.ts` — et compare
l'ensemble méthode + chemin à ce tableau :

- une route livrée sans ligne ici **fait échouer le test** ;
- une ligne qui ne correspond plus à aucune route **fait échouer le test** ;
- une route déclarée deux fois **fait échouer le test**.

Ce que le test ne fait PAS : vérifier que le consommateur déclaré appelle
vraiment la route. Cela reste une lecture humaine, faite au moment où la ligne
est écrite ou modifiée. Quand tu ajoutes une route, ajoute sa ligne dans le
même commit ; quand tu branches un client sur une route orpheline, corrige sa
ligne dans le même commit.

Les chemins sont ceux que **déclarent les contrôleurs**, sans le préfixe
global `/api/v1` que `configureApp` ajoute à l'exécution (les routes de santé,
elles, vivent réellement hors préfixe). Les paramètres portent la notation
OpenAPI : `{id}`.

## Les consommateurs

| Étiquette | Ce que c'est |
| --- | --- |
| **mobile** | L'application Flutter (`apps/mobile`). |
| **admin** | Le back-office Next.js authentifié (`apps/admin`, `src/lib/admin-api.ts`). |
| **web-public** | Les pages ouvertes d'`apps/admin` (`src/app/(public)`), celles qu'un lien d'e-mail ouvre dans un navigateur. |
| **externe** | Un prestataire qui appelle Carlys, pas l'inverse (webhooks signés). |
| **supervision** | L'orchestrateur et la métrologie, jamais un écran. |
| **aucun** | Personne, aujourd'hui. La raison et la date sont dans la colonne de droite. |

## Le tableau

### Santé et supervision

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /health` | **supervision** | orchestrateur / supervision |
| `GET /health/live` | **supervision** | orchestrateur / supervision |
| `GET /health/ready` | **supervision** | orchestrateur / supervision |

### Authentification

| Route | Consommateur | Où |
| --- | --- | --- |
| `POST /auth/change-password` | **mobile** | apps/mobile |
| `POST /auth/forgot-password` | **mobile** | apps/mobile |
| `POST /auth/login` | **mobile** | apps/mobile |
| `POST /auth/logout` | **mobile** | apps/mobile |
| `POST /auth/refresh` | **mobile** | apps/mobile |
| `POST /auth/register` | **mobile** | apps/mobile |
| `POST /auth/resend-verification` | **mobile** | apps/mobile |
| `POST /auth/reset-password` | **web-public** | apps/admin (pages publiques) |
| `DELETE /auth/sessions` | **mobile** | apps/mobile |
| `GET /auth/sessions` | **mobile** | apps/mobile |
| `DELETE /auth/sessions/{id}` | **mobile** | apps/mobile |
| `POST /auth/verify-email` | **web-public** | apps/admin (pages publiques) |

### Utilisateur courant

| Route | Consommateur | Où |
| --- | --- | --- |
| `DELETE /users/me` | **mobile** | apps/mobile |
| `GET /users/me` | **mobile** | apps/mobile |
| `PATCH /users/me` | **mobile** | apps/mobile |

### Catalogue d’exercices

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /equipment` | **aucun** (constaté le 7 septembre 2026) | Aucun écran ne filtre par matériel : la valeur voyage déjà dans chaque fiche d’exercice. Le back-office lit `/admin/equipment`. |
| `GET /exercises` | **mobile** | apps/mobile |
| `GET /exercises/{idOrSlug}` | **mobile** | apps/mobile |
| `GET /muscle-groups` | **mobile** | apps/mobile |

### Séances et séries

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /workout-sessions` | **mobile** | apps/mobile |
| `POST /workout-sessions` | **mobile** | apps/mobile |
| `GET /workout-sessions/{id}` | **mobile** | apps/mobile |
| `PATCH /workout-sessions/{id}` | **aucun** (constaté le 7 septembre 2026) | La file de synchronisation n’écrit une séance qu’à la création, à la clôture ou à l’abandon : aucune correction partielle n’existe côté application. |
| `POST /workout-sessions/{id}/abandon` | **mobile** | apps/mobile |
| `POST /workout-sessions/{id}/complete` | **mobile** | apps/mobile |
| `POST /workout-sessions/{id}/plan/skip` | **mobile** | apps/mobile |
| `POST /workout-sessions/{id}/sets` | **mobile** | apps/mobile |
| `DELETE /workout-sets/{id}` | **mobile** | apps/mobile |
| `PATCH /workout-sets/{id}` | **aucun** (constaté le 7 septembre 2026) | Corriger une série faite n’est proposé nulle part : l’application supprime la ligne et en repose une. |

### Modèles de séance

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /workout-templates` | **mobile** | apps/mobile |
| `DELETE /workout-templates/{id}` | **mobile** | apps/mobile |
| `GET /workout-templates/{id}` | **mobile** | apps/mobile |
| `PUT /workout-templates/{id}` | **mobile** | apps/mobile |

### Programmes

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /programs` | **mobile** | apps/mobile |
| `DELETE /programs/{id}` | **mobile** | apps/mobile |
| `GET /programs/{id}` | **mobile** | apps/mobile |
| `PUT /programs/{id}` | **mobile** | apps/mobile |

### Progression et mesures

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /body-metrics` | **mobile** | apps/mobile |
| `POST /body-metrics` | **mobile** | apps/mobile |
| `DELETE /body-metrics/{id}` | **mobile** | apps/mobile |
| `GET /progress/exercises/{exerciseId}` | **aucun** (constaté le 7 septembre 2026) | La courbe par exercice n’a pas encore d’écran ; l’écran Progression montre le résumé et les records. |
| `GET /progress/overview` | **mobile** | apps/mobile |
| `GET /progress/records` | **mobile** | apps/mobile |

### Nutrition

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /nutrition/meals` | **mobile** | apps/mobile |
| `POST /nutrition/meals` | **mobile** | apps/mobile |
| `DELETE /nutrition/meals/{id}` | **mobile** | apps/mobile |
| `GET /nutrition/metabolism` | **mobile** | apps/mobile |

### Communauté

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /community/blocks` | **mobile** | apps/mobile |
| `DELETE /community/blocks/{userId}` | **mobile** | apps/mobile |
| `POST /community/blocks/{userId}` | **mobile** | apps/mobile |
| `GET /community/challenges` | **mobile** | apps/mobile |
| `DELETE /community/challenges/{id}/join` | **mobile** | apps/mobile |
| `POST /community/challenges/{id}/join` | **mobile** | apps/mobile |
| `POST /community/encouragements` | **mobile** | apps/mobile |
| `DELETE /community/encouragements/{id}` | **mobile** | apps/mobile |
| `GET /community/feed` | **mobile** | apps/mobile |
| `GET /community/friend-codes/{code}` | **mobile** | apps/mobile |
| `GET /community/friends` | **mobile** | apps/mobile |
| `DELETE /community/friends/{userId}` | **mobile** | apps/mobile |
| `GET /community/profile` | **mobile** | apps/mobile |
| `PATCH /community/profile` | **mobile** | apps/mobile |
| `POST /community/quiz-answers` | **mobile** | apps/mobile |
| `POST /community/reports` | **mobile** | apps/mobile |
| `GET /community/requests` | **mobile** | apps/mobile |
| `POST /community/requests` | **mobile** | apps/mobile |
| `POST /community/requests/{id}/accept` | **mobile** | apps/mobile |
| `POST /community/requests/{id}/decline` | **mobile** | apps/mobile |

### Coach IA

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /coach/conversations` | **mobile** | apps/mobile |
| `POST /coach/conversations` | **mobile** | apps/mobile |
| `GET /coach/conversations/{id}` | **mobile** | apps/mobile |
| `POST /coach/conversations/{id}/messages` | **mobile** | apps/mobile |
| `POST /coach/proposals/{id}/accepted` | **mobile** | apps/mobile |

### Abonnements et droits

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /entitlements` | **mobile** | apps/mobile |
| `POST /subscriptions/checkout` | **mobile** | apps/mobile |
| `GET /subscriptions/me` | **mobile** | apps/mobile |
| `GET /subscriptions/offers` | **mobile** | apps/mobile |
| `POST /subscriptions/portal` | **mobile** | apps/mobile |

### Notifications

| Route | Consommateur | Où |
| --- | --- | --- |
| `DELETE /notifications/device-tokens` | **mobile** | apps/mobile |
| `POST /notifications/device-tokens` | **mobile** | apps/mobile |
| `GET /notifications/preferences` | **mobile** | apps/mobile |
| `PATCH /notifications/preferences` | **mobile** | apps/mobile |

### Webhooks de paiement

| Route | Consommateur | Où |
| --- | --- | --- |
| `POST /webhooks/revenuecat` | **externe** | prestataire de paiement |
| `POST /webhooks/stripe` | **externe** | prestataire de paiement |

### Administration

| Route | Consommateur | Où |
| --- | --- | --- |
| `GET /admin/audit-logs` | **admin** | apps/admin (back-office) |
| `POST /admin/auth/login` | **admin** | apps/admin (back-office) |
| `GET /admin/auth/me` | **admin** | apps/admin (back-office) |
| `GET /admin/community/reports` | **admin** | apps/admin (back-office) |
| `PATCH /admin/community/reports/{id}` | **admin** | apps/admin (back-office) |
| `GET /admin/equipment` | **admin** | apps/admin (back-office) |
| `GET /admin/exercises` | **admin** | apps/admin (back-office) |
| `DELETE /admin/exercises/{id}` | **admin** | apps/admin (back-office) |
| `PATCH /admin/exercises/{id}/categories` | **admin** | apps/admin (back-office) |
| `PUT /admin/exercises/{id}/image` | **admin** | apps/admin (back-office) |
| `PUT /admin/exercises/{id}/mesh` | **aucun** (constaté le 7 septembre 2026) | Rien n’affiche de maillage 3D, ni dans l’application ni dans le back-office : la route existe pour le jour où. |
| `PATCH /admin/exercises/{id}/publication` | **admin** | apps/admin (back-office) |
| `POST /admin/exercises/{id}/restore` | **admin** | apps/admin (back-office) |
| `GET /admin/media` | **admin** | apps/admin (back-office) |
| `POST /admin/media` | **admin** | apps/admin (back-office) |
| `DELETE /admin/media/{id}` | **admin** | apps/admin (back-office) |
| `GET /admin/muscle-groups` | **admin** | apps/admin (back-office) |
| `POST /admin/muscle-groups` | **admin** | apps/admin (back-office) |
| `DELETE /admin/muscle-groups/{id}` | **admin** | apps/admin (back-office) |
| `PATCH /admin/muscle-groups/{id}` | **admin** | apps/admin (back-office) |
| `GET /admin/overview` | **admin** | apps/admin (back-office) |
| `GET /admin/users` | **admin** | apps/admin (back-office) |
| `GET /admin/users/{id}` | **admin** | apps/admin (back-office) |
| `PUT /admin/users/{id}/entitlements` | **admin** | apps/admin (back-office) |
| `PATCH /admin/users/{id}/status` | **admin** | apps/admin (back-office) |
