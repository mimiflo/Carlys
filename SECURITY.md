# Politique de sécurité — Carlys

Ce document décrit comment signaler une vulnérabilité, les règles de sécurité
appliquées **dès maintenant** (Étape 1 — fondation) et les engagements **cibles**
qui seront tenus au fur et à mesure des tranches verticales (Étapes 2 à 7,
voir `CLAUDE.md`). Une mesure marquée « cible (Étape N) » n'est **pas encore
implémentée** : elle est planifiée et documentée pour être vérifiable à sa livraison.

---

## 1. Signaler une vulnérabilité

- **Contact** : envoyez un e-mail à `florian.mottet2005@gmail.com` avec l'objet
  `[SECURITY] Carlys — <résumé court>`.
- **Ne créez pas d'issue GitHub publique** pour une vulnérabilité : la divulgation
  se fait de manière coordonnée, après correction.
- Décrivez : la version/commit concerné, les étapes de reproduction, l'impact
  estimé et, si possible, une preuve de concept minimale.

### Délais d'engagement

| Étape | Délai visé |
| --- | --- |
| Accusé de réception | 72 heures |
| Première évaluation (sévérité, périmètre) | 7 jours |
| Correction d'une vulnérabilité critique ou haute | 30 jours |
| Correction d'une vulnérabilité moyenne ou faible | 90 jours |
| Divulgation coordonnée | après publication du correctif, au plus tard 90 jours après le signalement |

Seule la branche `main` est supportée : le projet est en pré-version (0.x),
aucune version antérieure ne reçoit de correctif.

---

## 2. Règles applicables dès maintenant (Étape 1 — en place)

### Secrets et configuration

- **Aucun secret n'est commité.** Les fichiers `.env` et `.env.*` sont ignorés
  par Git (`.gitignore`) ; seuls les `.env.example` sont versionnés et ne
  contiennent **que des valeurs factices** (`.env.example` racine,
  `apps/api/.env.example`, `apps/admin/.env.example`).
- **Détection de secrets en CI** : TruffleHog (`.github/workflows/security-ci.yml`)
  s'exécute sur chaque pull request, chaque push sur `main` et chaque lundi à
  06:00 UTC (`--results=verified,unknown`).
- **Audit de dépendances en CI** : `pnpm audit --audit-level high` dans le même
  workflow (vulnérabilités `high` et `critical` bloquantes).
- **Forçages de versions transitives** : quand une dépendance vulnérable est
  imposée par un paquet intermédiaire qui l'épingle, la correction passe par
  `pnpm.overrides` dans le `package.json` racine, avec la borne d'origine
  conservée dans la clé (`"paquet@<version-corrigée>": "version-corrigée"`) —
  ainsi l'entrée devient sans effet le jour où l'amont met à jour, et elle
  n'est pas silencieusement oubliée. Un forçage n'est légitime qu'après avoir
  vérifié que le paquet consommateur continue de fonctionner : les notes de
  version majeures sont lues, et le chemin d'appel réel est exécuté.

  | Paquet | Forcé à | Pourquoi |
  | ------ | ------- | -------- |
  | `deepmerge-ts` | `8.0.1` | GHSA-ggr8-5vv4-36mx (épuisement de pile, aucune détection de cycle). Imposé par `prisma > @prisma/config`, qui épingle `7.1.5` **jusque dans sa dernière version** : monter Prisma ne corrige rien. |
  | `js-yaml` | `5.2.3` | Exécution de code à l'analyse (branche 5). |
  | `nanoid` | `3.3.18` | Boucle infinie sur une taille non entière. |
  | `uuid` | `11.1.1` | Correctifs de la chaîne amont. |
- **Configuration validée au démarrage** : le schéma Zod
  `apps/api/src/config/env.schema.ts` vérifie toutes les variables d'environnement ;
  le serveur **refuse de démarrer** si une variable essentielle est absente ou
  invalide (message d'erreur explicite, sans valeur sensible).
- **Valeurs de développement refusées en production**
  (`apps/api/src/config/env.production.ts`) : avec `NODE_ENV=production`,
  `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`,
  `S3_PUBLIC_BASE_URL`, `SMTP_HOST`, `EMAIL_FROM`, `PUBLIC_APP_URL` et
  `CORS_ORIGINS` doivent être fournis explicitement ; une URL publique vers
  `localhost` ou `127.0.0.1`, un identifiant `carlys-dev*` ou une URL publique
  en `http://` font échouer le démarrage. Sans cela, l'API démarrait « avec
  succès » en envoyant ses e-mails à un Mailpit inexistant et en servant des
  médias depuis `localhost`.

### Surface HTTP de l'API (`apps/api`)

- **Validation stricte des entrées** : `ValidationPipe` global avec
  `whitelist: true` et `forbidNonWhitelisted: true`
  (`apps/api/src/app/configure-app.ts`) — toute propriété non déclarée dans un
  DTO est rejetée.
- **Helmet** activé globalement (en-têtes de sécurité HTTP).
- **CORS restreint** aux origines listées dans `CORS_ORIGINS`
  (par défaut `http://localhost:3001` en développement).
- **Rate limiting** global via `@nestjs/throttler` : 100 requêtes / 60 secondes
  par défaut (`RATE_LIMIT_TTL_SECONDS`, `RATE_LIMIT_MAX_REQUESTS`,
  constantes dans `packages/shared-config`).
- **Adresse du client derrière un proxy** : `TRUST_PROXY_HOPS` (défaut `0`)
  fixe le nombre de proxys de confiance ; sans lui, le rate limiting, le
  verrouillage et l'audit ne verraient que l'adresse du reverse proxy. Jamais
  « tout faire confiance » : voir `docs/security/reverse-proxy.md`.
- **Taille des corps de requêtes limitée à 1 Mo** (`MAX_JSON_BODY_SIZE`,
  appliquée dans `apps/api/src/main.ts` pour JSON et urlencoded).
- **Erreurs sans fuite d'informations** : le filtre global
  `apps/api/src/common/filters/all-exceptions.filter.ts` normalise toute
  exception en enveloppe `{ error: { code, message, details, requestId } }` ;
  pour les erreurs 5xx, le message renvoyé est générique (« Une erreur interne
  est survenue. ») — les détails internes ne partent que dans les logs serveur.
- **Swagger désactivé en production** (`/api/docs` disponible uniquement hors
  production, surchargeable par `SWAGGER_ENABLED`).

### Endpoints techniques

- `/health`, `/health/live`, `/health/ready` : sondes sans donnée sensible.
- `/metrics` (Prometheus) : **libre hors production ; en production, exige un
  Bearer token** `METRICS_TOKEN` (16 caractères minimum). Si le token n'est pas
  configuré en production, l'endpoint répond 404 (comme s'il n'existait pas).
  La comparaison du token est en **temps constant**
  (`apps/api/src/modules/metrics/metrics-auth.guard.ts`).

### Journalisation

- Logs **Pino structurés** (nestjs-pino), corrélés au `requestId`
  (en-tête `x-request-id`, généré ou validé par motif `^[\w-]{1,64}$`).
- **Rédaction automatique** des en-têtes `authorization` et `cookie`
  (supprimés des logs — `apps/api/src/app/app.module.ts`).
- Règle permanente : **aucun mot de passe, token, secret ou donnée de paiement
  ne doit jamais apparaître dans un log**, y compris en niveau `debug`.
  Toute nouvelle fonctionnalité étend la liste de rédaction si nécessaire.

### Base de données et migrations

- Accès PostgreSQL exclusivement via **Prisma** (client typé, requêtes
  paramétrées). Le schéma est encore vide à l'Étape 1 ; les modèles arrivent
  par tranches verticales.
- En production : `prisma migrate deploy` **avant** la bascule du trafic,
  jamais au démarrage du conteneur. La CI (`api-ci.yml`) exécute
  `prisma validate` et détecte les migrations manquantes.

---

## 3. Engagements cibles par domaine

Chaque engagement ci-dessous est **cible** : il devient contraignant à la
livraison de l'étape indiquée, et toute revue de code de cette étape doit le
vérifier.

### Mots de passe — cible (Étape 2)

- Hachage **Argon2id** exclusivement (jamais MD5/SHA/bcrypt faible).
- Un mot de passe (ou son hash) n'est **jamais loggé** et **jamais retourné**
  par l'API, y compris dans les messages d'erreur et les payloads Swagger.
- Réinitialisation par jeton à usage unique et à expiration courte.
- Conception détaillée : `docs/security/authentication.md`.

### Tokens et sessions — cible (Étape 2)

- **Access token JWT court** (~15 minutes), avec `audience` et `issuer`
  vérifiés à chaque requête.
- **Refresh token opaque rotatif**, stocké **hashé** en base (jamais en clair),
  lié à une **session par appareil**.
- **Rotation à chaque rafraîchissement** + **détection de réutilisation** :
  la réutilisation d'un refresh token déjà consommé révoque toute la famille
  de tokens (déconnexion forcée de la session compromise).
- **Révocation** : déconnexion ciblée par appareil et déconnexion globale.
- Côté mobile : stockage exclusivement dans `flutter_secure_storage`
  (jamais SharedPreferences).

### API — en place (Étape 1), maintenu à chaque étape

- **DTO dédiés en whitelist** pour chaque endpoint (aucune entité Prisma
  exposée directement, aucun champ non déclaré accepté).
- Taille maximale des requêtes : **1 Mo**.
- **Pagination bornée** : 20 éléments par défaut, 100 maximum
  (`packages/shared-config`).
- **Requêtes Prisma sécurisées** : jamais de SQL brut construit à partir
  d'entrées non contrôlées (`$queryRawUnsafe` interdit ; `$queryRaw` tagué
  uniquement, avec justification écrite).

### Médias — cible (au premier usage du stockage, bucket `carlys-media`)

- **Upload par URL signée** (pas d'upload transitant par l'API en clair).
- Vérification côté serveur du **type MIME, de la taille et de l'extension**.
- **Noms de fichiers générés** (UUID) — jamais le nom fourni par le client.
- **Bucket privé** ; lecture via **URL signées à expiration courte**.
- En développement, MinIO local (`docker-compose.yml`) reproduit ce modèle.

### Abonnements et paiements — cible (Étape 6)

- **Webhooks signés** (signature vérifiée avant tout traitement),
  **idempotents** (rejeu sans effet) et **journalisés**.
- Les **droits (entitlements) sont validés côté serveur uniquement** — jamais
  décidés par le client.
- Aucune donnée de carte bancaire ne transite ni n'est stockée par Carlys
  (délégué à Stripe / RevenueCat) ; aucune donnée de paiement dans les logs.

### Données personnelles — cible (transversal, renforcé aux Étapes 2 et 7)

- **Consentement** explicite recueilli et tracé.
- **Export** des données personnelles à la demande de l'utilisateur.
- **Suppression du compte à la demande — en place** (`DELETE /api/v1/users/me`,
  mot de passe exigé, `AccountService`). En **une transaction** : sessions
  révoquées, compte passé `DELETED`, adresse réécrite en
  `supprime+<id>@carlys.invalid` (l'adresse d'origine redevient disponible
  pour une nouvelle inscription), code ami réécrit hors alphabet (plus aucun
  scan ni saisie ne le résout), `displayName`, `birthDate`, `sex` et
  `heightCm` effacés, jetons d'appareil supprimés. **Conservé, et pourquoi** :
  la ligne `User` avec son identifiant (cité par le journal d'audit, qui
  doit rester lisible), la crédential (un lien de réinitialisation encore
  valide ne doit pas produire une erreur serveur), et l'historique
  d'activité (séances, séries, records, mesures, journal alimentaire,
  conversations coach) rattaché à cet identifiant, qui ne porte plus rien
  qui identifie la personne. **Non fait** : aucune purge différée de cet
  historique n'existe encore (pas de travail de fond dans l'API).
- **Rétention limitée des logs** applicatifs.
- **Chiffrement en transit** (TLS) sur tous les environnements distants.
- **Audit des accès administrateurs** (Étape 7 : rôles, permissions, journal
  d'audit).

---

## 4. Récapitulatif : en place vs cible

| Mesure | Statut |
| --- | --- |
| Secrets hors dépôt, `.env` ignorés, `.env.example` factices | En place |
| TruffleHog + `pnpm audit --audit-level high` en CI | En place |
| Config Zod bloquante au démarrage | En place |
| Validation `whitelist` + `forbidNonWhitelisted`, Helmet, CORS restreint | En place |
| Rate limiting 100 req/60 s, corps limité à 1 Mo | En place |
| Enveloppes d'erreur sans fuite (5xx génériques) | En place |
| `/metrics` protégé par Bearer token en production (comparaison temps constant) | En place |
| Logs Pino avec `requestId`, `authorization`/`cookie` rédigés | En place |
| Argon2id, JWT court, refresh rotatif hashé, détection de réutilisation | Cible (Étape 2) |
| Upload signé, bucket privé, URL signées courtes | Cible (premier usage médias) |
| Webhooks signés idempotents, entitlements côté serveur | Cible (Étape 6) |
| Rôles/permissions/audit admin | Cible (Étape 7) |
| Suppression de compte : identité libérée en une transaction, réinscription possible | En place |
| Consentement, export, purge différée de l'historique d'activité | Cible (transversal) |

---

*Document lié : `docs/security/authentication.md` (conception détaillée de
l'authentification, implémentation prévue à l'Étape 2).*
