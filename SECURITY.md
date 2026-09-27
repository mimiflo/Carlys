# Politique de sécurité — Carlys

Ce document décrit comment signaler une vulnérabilité et les règles de sécurité
appliquées. Les sept étapes de `CLAUDE.md` sont livrées : une mesure marquée
« en place » est implémentée et vérifiable dans le code cité ; une mesure
marquée « cible » n'existe **pas encore**, et le document le dit.

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

## 2. Règles en place (fondation et surface HTTP)

### Secrets et configuration

- **Aucun secret n'est commité.** Les fichiers `.env` et `.env.*` sont ignorés
  par Git (`.gitignore`) ; seuls les `.env.example` sont versionnés et ne
  contiennent **que des valeurs factices** (`.env.example` racine,
  `apps/api/.env.example`, `apps/admin/.env.example`).
- **Détection de secrets en CI** : TruffleHog (`.github/workflows/security-ci.yml`)
  s'exécute sur chaque pull request, chaque poussée sur la branche de travail
  comme sur `main`, et chaque lundi à 06:00 UTC. La branche de travail est
  nommée explicitement parce que le dépôt avance par poussées directes :
  s'en tenir à `main` ne signalait un jeton qu'après la fusion, alors qu'il est
  compromis dès qu'il a quitté le poste.
  Les arguments sont `--results=verified,unknown,unverified` : `unverified`
  désigne les secrets que TruffleHog a confirmés **morts** auprès du
  fournisseur. Ils font échouer la CI comme les autres, parce que la règle du
  dépôt est « aucun secret commité », sans exception pour les jetons révoqués —
  une clé révoquée reste une identité publiée, souvent réutilisée ailleurs.
  Révoquer répare la fuite, cela n'efface pas le commit : la reprise
  d'historique reste nécessaire.
  **Deux épingles, dont une que Dependabot ne voit pas** : l'action est fixée
  par SHA de commit, et l'IMAGE qu'elle exécute par tag et empreinte
  (`version: 3.97.9@sha256:…`) — sans cette seconde épingle, l'action lançait
  `trufflehog:latest`, le dernier binaire publié par un tiers, sur tout
  l'historique. Dependabot ne suit que les `uses:` : l'image se monte **à la
  main**, en même temps que l'action. Le jeton du dépôt n'est plus laissé dans
  `.git/config` pendant le scan (`persist-credentials: false`).
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
- **Adresse du client derrière un proxy** : `TRUST_PROXY_HOPS` (défaut `0`,
  `2` en production — le proxy réseau puis le Nginx du serveur) fixe le nombre
  de proxys de confiance ; sans lui, la limitation de débit et l'audit ne
  verraient que l'adresse du reverse proxy. Le verrouillage de compte, lui,
  n'est PAS concerné : il s'indexe sur l'identité (`lockout.reserveAttempt(email)`),
  jamais sur l'adresse. Jamais « tout faire confiance » — et un compteur de
  sauts ne protège d'un `X-Forwarded-For` forgé QUE si le proxy de tête écrase
  l'en-tête au lieu d'y ajouter : voir `docs/security/reverse-proxy.md`.
- **Taille des corps de requêtes limitée à 1 Mo** (`MAX_JSON_BODY_SIZE`)
  pour JSON, urlencoded et le corps brut des webhooks, posée dans
  `apps/api/src/app/configure-app.ts` — donc la même en production et dans
  les tests e2e. Un corps trop gros, mal formé ou d'un type refusé rend 413,
  400 ou 415, journalisé en `warn`, jamais un 500. Deux routes multipart ont
  leur propre plafond, vérifié par l'API : les médias du back-office
  (`MEDIA_MAX_UPLOAD_BYTES`, 20 Mio par défaut, 64 Mio au plus en transport)
  et la photo d'un repas (5 Mio, `MEAL_PHOTO_MAX_BYTES`) ; Nginx les laisse
  passer (64 Mo et 6 Mo) et coupe tout le reste à 1 Mo.
- **Erreurs sans fuite d'informations** : le filtre global
  `apps/api/src/common/filters/all-exceptions.filter.ts` normalise toute
  exception en enveloppe `{ error: { code, message, details, requestId } }` ;
  pour les erreurs 5xx, le message renvoyé est générique (« Une erreur interne
  est survenue. ») — les détails internes ne partent que dans les logs serveur.
  Seule exception : un 503 levé en `UserFacingUnavailableException`
  (`common/filters/user-facing-unavailable.exception.ts`), dont le message
  est écrit pour la personne et ne cite rien d'interne — aujourd'hui le seul
  refus de suppression du compte quand Stripe n'a pas résilié.
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
- **Rédaction automatique** des en-têtes `authorization` et `cookie`, et des
  champs `to`, `email`, `*.email` et `identifier` (supprimés des logs —
  `apps/api/src/app/app.module.ts`). L'API n'écrit pas d'adresse e-mail en
  clair : l'envoi d'e-mails, le verrouillage et l'audit d'un échec de
  connexion, mobile comme back-office (`auth.login_failed`,
  `auth.login_blocked_lockout`, `admin.login_failed`,
  `admin.login_blocked_lockout` : `metadata.emailHash`), n'en gardent
  qu'une empreinte **à clé** — un HMAC-SHA-256 tronqué
  (`common/utilities/log-privacy.ts`), sous une clé dérivée par HKDF de
  `JWT_ACCESS_SECRET` (`AppConfigService.logFingerprintKey`). Un SHA-256 nu
  se renversait par dictionnaire ; sans la clé, une adresse candidate ne se
  vérifie plus. Contrepartie : changer `JWT_ACCESS_SECRET` change aussi les
  empreintes, la corrélation ne traverse pas la rotation. Les lignes d'audit
  écrites avant ce changement (7921f3f) portaient l'adresse en clair
  (`metadata.email`, back-office ET mobile) : la migration de données
  `20260927200000_audit_adresses_et_empreintes_nues` la remplace par
  `emailHash: null`, et passe aussi à `null` toute `emailHash` datée d'avant
  le code HMAC ou qui n'a pas sa forme (12 caractères hexadécimaux) — une
  empreinte sans clé, qu'aucune version du dépôt n'a écrite dans l'audit
  mais qu'aucune forme ne distingue d'un HMAC. Pas de réécriture en HMAC :
  la clé dérive de `JWT_ACCESS_SECRET`, que ni la base ni une migration
  versionnée ne doivent connaître ; la corrélation de ces anciens échecs est
  perdue. Un refus SMTP est journalisé sans les adresses qu'il cite. **La
  ligne de requête ne porte plus d'adresse** : Pino (`req.url`,
  `req.query`, jamais le corps) et le journal d'accès Nginx la recopient,
  et la recherche du back-office, qui porte souvent une adresse, est
  désormais un `POST /admin/users/search`, terme et curseur dans le corps
  (`SearchManagedUsersDto`) ; l'ancienne `GET /admin/users?search=…` est
  supprimée. `apps/admin/src/app/users/page.test.tsx` échoue si l'adresse
  cherchée apparaît dans une URL (requête, historique, barre d'adresse).
- **Journal Nginx sans jetons** : le format `carlys_sans_jeton`
  (`infrastructure/nginx/conf.d/carlys-journal.conf`) masque la valeur de
  tout paramètre `…token=` dans la requête et le Referer du journal d'accès,
  et les vhosts `app` écartent `/verify-email` et `/reset-password` du
  journal d'erreurs (`error_log … emerg`), qui recopierait sinon la ligne de
  requête brute à chaque 502. Vérifié par `infrastructure/nginx/tests/`.
- Règle permanente : **aucun mot de passe, token, secret ou donnée de paiement
  ne doit jamais apparaître dans un log**, y compris en niveau `debug`.
  Toute nouvelle fonctionnalité étend la liste de rédaction si nécessaire.

### Base de données et migrations

- Accès PostgreSQL exclusivement via **Prisma** (client typé, requêtes
  paramétrées) ; schéma et migrations décrits dans `docs/database/schema.md`.
- En production : `prisma migrate deploy` **avant** la bascule du trafic,
  jamais au démarrage du conteneur, et précédé d'un dump de la base
  (`scripts/server/deploy.sh`, `_sauvegarde.sh`). La CI (`api-ci.yml`)
  exécute `prisma validate`, détecte les migrations manquantes et applique
  `migrate deploy` avant les e2e.

### Sauvegardes

- Dump PostgreSQL chaque nuit (`scripts/server/backup.sh`), gardé 14 jours
  (`CARLYS_BACKUP_RETENTION_DAYS`) ; dump d'avant-migration à chaque
  déploiement de production, gardé au plus 30 jours
  (`CARLYS_BACKUP_PREMIGRATION_MAX_DAYS`) et au plus 3 dumps
  (`CARLYS_BACKUP_PREMIGRATION_KEEP`). La purge est un `find -mtime +J`
  nocturne : un fichier ne part qu'une fois âgé de J + 1 jours révolus, soit
  16 jours au plus pour la nuit, 32 pour l'avant-migration (les bornes
  qu'annonce la politique). Elle ne tourne que pour un environnement dont
  la sauvegarde de la nuit a RÉUSSI : une panne suspend la rotation (rien
  n'est jeté tant que rien de neuf ne l'a remplacé) et lève l'alerte
  « Sauvegarde des bases: ECHEC » (`_alert.sh`).
- Copie **hors machine** chiffrée par gpg (AES-256, authentifiée) avant de
  partir vers un stockage S3 d'un autre fournisseur (`_hors_site.sh`), dès
  que `/srv/carlys/sauvegarde-distante.env` est rempli ; rétention distante
  `CARLYS_SAUVEGARDE_DISTANTE_RETENTION_JOURS` (14 par défaut), **toutes
  versions comprises** (`mc rm --versions`) : sur un bucket versionné, un
  effacement simple ne poserait qu'un marqueur et garderait le dump sans
  limite. Un verrouillage d'objets plus long que la rétention fait échouer
  l'envoi (alerte) au lieu de garder les données au-delà de la borne.
  `carlysctl doctor` avertit tant que la production tourne sans elle.
- Le bucket **privé** des photos de repas n'est **jamais** sauvegardé : une
  photo effacée ne survit nulle part (choix documenté dans `backup.sh`).
- Ces durées sont celles qu'annonce `docs/legal/privacy.md` (section 6) :
  les changer, c'est changer le texte.

---

## 3. Engagements par domaine

Chaque domaine dit ce qui est **en place**, et ce qui reste **cible**.

### Mots de passe — en place (Étape 2)

- Hachage **Argon2id** exclusivement (jamais MD5/SHA/bcrypt faible).
- Un mot de passe (ou son hash) n'est **jamais loggé** et **jamais retourné**
  par l'API, y compris dans les messages d'erreur et les payloads Swagger.
- Réinitialisation par jeton à usage unique et à expiration courte (60 min) ;
  au plus un lien par minute et 5 par heure pour un même compte, sous verrou
  PostgreSQL, la réponse restant 202 dans tous les cas.
- **Verrouillage par compte** : 5 échecs (`AUTH_MAX_LOGIN_ATTEMPTS`) donnent
  429 pendant 15 minutes, sur la connexion mobile, la connexion du
  back-office et, avec un compteur distinct, la ré-authentification
  (changement de mot de passe, suppression de compte). L'essai est
  **réservé** de façon atomique (`LockoutService.reserveAttempt`, `INCR`
  Redis) AVANT la vérification Argon2 : une rafale parallèle depuis
  plusieurs adresses IP ne dépasse pas le seuil.
- Conception détaillée : `docs/security/authentication.md`.

### Tokens et sessions — en place (Étape 2)

- **Access token JWT court** (~15 minutes), avec `audience` et `issuer`
  vérifiés à chaque requête.
- **Refresh token opaque rotatif**, stocké **hashé** en base (jamais en clair),
  lié à une **session par appareil**.
- **Rotation à chaque rafraîchissement** + **détection de réutilisation** :
  la réutilisation d'un refresh token déjà consommé révoque toute la famille
  de tokens (déconnexion forcée de la session compromise).
- **Révocation** : déconnexion ciblée par appareil et déconnexion globale.
  Les **jetons push** (`DeviceToken.sessionId`) tombent avec la session qui
  les a enregistrés, dans la même transaction : appareil déconnecté,
  « déconnecter les autres appareils », changement et réinitialisation de
  mot de passe, réutilisation de refresh détectée, reprise d'un compte par
  la connexion sociale, suspension par l'administration. Une session
  expirée ne reçoit plus rien (`listTokens` ne sert que les sessions
  vivantes). Côté mobile, le jeton FCM est effacé de l'appareil à chaque
  déconnexion et à chaque expiration de session.
- **Connexion Apple et Google** (`POST /auth/social`) : jeton d'identité
  vérifié (signature JWKS, `iss`, `aud`, `sub`/`iat`/`exp` exigés, âge
  maximal), sans nonce — risque accepté, écrit dans
  `docs/security/authentication.md`.
- Côté mobile : stockage exclusivement dans `flutter_secure_storage`
  (jamais SharedPreferences).

### API — en place, maintenu à chaque étape

- **DTO dédiés en whitelist** pour chaque endpoint (aucune entité Prisma
  exposée directement, aucun champ non déclaré accepté).
- Taille maximale des requêtes : **1 Mo**, sauf les deux routes multipart
  décrites plus haut.
- **Pagination bornée** : 20 éléments par défaut, 100 maximum
  (`packages/shared-config`).
- **Requêtes Prisma sécurisées** : jamais de SQL brut construit à partir
  d'entrées non contrôlées (`$queryRawUnsafe` interdit ; `$queryRaw` tagué
  uniquement, avec justification écrite).

### Médias — en place

- **Deux buckets, deux régimes.** `S3_BUCKET` (`carlys-media`) porte le
  catalogue public (photos d'exercices) : lecture **anonyme** par
  `S3_PUBLIC_BASE_URL`, puisqu'il ne dit rien de personne.
  `S3_PRIVATE_BUCKET` porte les photos de repas : **aucune** lecture
  anonyme, servi **en flux par l'API** au seul propriétaire
  (`GET /nutrition/meals/:id/photo`, 404 opaque pour les autres). Aucune URL
  signée n'est émise.
- **Tout dépôt passe par l'API** en multipart (pas d'URL de dépôt signée) :
  médias du back-office (permission `media:write`) et photo d'un repas.
- Vérification côté serveur de la **taille** et du **type** : liste blanche
  de types MIME pour les médias du back-office (type annoncé par le dépôt,
  réservé à des comptes admin), JPEG **prouvé par les octets** pour la
  photo d'un repas, débarrassée de ses métadonnées (EXIF, GPS, XMP, IPTC)
  avant stockage.
- **Noms d'objets générés** — jamais le nom fourni par le client.
- En développement, MinIO local (`docker-compose.yml`) reproduit ce modèle.

### Abonnements et paiements — en place (Étape 6)

- **Webhooks signés** (signature vérifiée avant tout traitement),
  **idempotents** (rejeu sans effet) et **journalisés**.
- Les **droits (entitlements) sont validés côté serveur uniquement** — jamais
  décidés par le client. Une décision manuelle du back-office (octroi ou
  coupure ; une coupure SANS raison est refusée par l'API, 400, quel que
  soit le client : `SetEntitlementDto.reason`, 1 à 500 caractères sans les
  espaces autour, et l'union `managedEntitlementDecisionSchema` du contrat ;
  l'octroi la garde facultative, et l'audit l'enregistre, nulle à défaut)
  prime sur l'abonnement jusqu'à ce
  qu'un administrateur « rende la main »
  (`DELETE /admin/users/:id/entitlements/:key`, permission
  `entitlement:grant`, auditée `admin.entitlement_released`).
- Aucune donnée de carte bancaire ne transite ni n'est stockée par Carlys
  (délégué à Stripe / RevenueCat) ; aucune donnée de paiement dans les logs.

### Données personnelles — en place, sauf mention contraire

- **Consentement** : cible. Aucune trace horodatée de l'acceptation des
  textes n'est enregistrée ; la phrase de consentement est affichée sous
  les boutons qui créent un compte (inscription, et Google ou Apple à la
  connexion).
- **Export** des données personnelles à la demande : cible (à la main, sur
  demande écrite, tant qu'aucun outil n'existe).
- **Suppression du compte à la demande — en place** (`DELETE /api/v1/users/me`,
  mot de passe exigé, `AccountService`). Un compte né d'une connexion Apple
  ou Google n'a pas de mot de passe : la route répond **409** et renvoie à
  « Mot de passe oublié », qui en pose un. **D'abord, l'abonnement qui
  prélève** : les abonnements Stripe actifs, en essai ou en retard de
  paiement sont résiliés chez Stripe AVANT toute suppression
  (`AccountBillingService`, `DELETE /v1/subscriptions/{id}` par
  `StripeSubscriptionClient`, délai de 10 s ; un 404 vaut succès, l'abonnement
  n'existant plus ; clé d'idempotence par TENTATIVE, Stripe gardant 24 h la
  première réponse d'une clé, échec compris). Si Stripe échoue : **503**
  `SERVICE_UNAVAILABLE`, message écrit pour la personne
  (`UserFacingUnavailableException`), et RIEN n'est supprimé. En production,
  un abonnement Stripe à résilier sans clé Stripe configurée est un refus ;
  hors production, la suppression passe, journalisée. Un abonnement de
  magasin (RevenueCat) ne se résilie que dans le magasin : la réponse **200**
  porte `storeSubscriptionStillActive` (`AccountDeletionResult`), et l'appli
  dit de le résilier là-bas. Puis, en **une transaction** : sessions
  **supprimées** avec leurs refresh tokens (elles portaient `ipAddress`,
  `userAgent`, `deviceName` et `devicePlatform` — des données personnelles
  qui ne survivent pas au compte), compte passé `DELETED`, adresse réécrite
  en `supprime+<id>@carlys.invalid` (l'adresse d'origine redevient disponible
  pour une nouvelle inscription), code ami réécrit hors alphabet (plus aucun
  scan ni saisie ne le résout), `displayName`, `birthDate`, `sex` et
  `heightCm` effacés, jetons d'appareil et **identités externes** (Apple,
  Google) supprimés, **photos de repas
  effacées** (leurs lignes `MealPhoto` dans la transaction ; puis, hors
  transaction puisque S3 n'en a pas, tout le préfixe
  `meal-photos/<userId>/` du bucket PRIVÉ `S3_PRIVATE_BUCKET`, orphelins
  compris ; un stockage muet est journalisé en erreur avec le `requestId`, ne
  fait pas échouer la suppression, et laisse des objets que plus aucune
  ligne ne cite, repris par `dist/cli/meal-photos-sweep`, que la
  supervision lance chaque jour ; la ligne `User` est verrouillée en
  premier, pour qu'un dépôt de photo en cours ne puisse pas écrire la sienne
  après l'effacement), abonnements résiliés passés `CANCELED`, et **retrait
  immédiat de la communauté** (`CommunityWithdrawalService`) : sortie de la
  ligue (`joinsLeague: false`, la ligne de la semaine restant comptée au
  règlement, sans nom), défis entre amis LANCÉS supprimés (un signalement
  garde ses clichés), défi échu pas encore réglé RÉGLÉ d'abord avec elle
  (rangs figés), lignes de membre retirées de tous les autres, défi en
  cours resté sans personne face à son créateur passé `CANCELLED` avec
  `closedAt` (il ne s'accepte plus), encouragements ENVOYÉS supprimés. La ligne d'audit
  (`account.deleted`, ou `account.deleted_by_operator`) note
  `stripeSubscriptionsCanceled` et `storeSubscriptionStillActive`. **Conservé, et
  pourquoi** :
  la ligne `User` avec son identifiant (cité par le journal d'audit, qui
  doit rester lisible — l'audit garde sa **propre** `ipAddress` par
  événement, y compris celui de la suppression, pour l'enquête), la
  crédential (un lien de réinitialisation encore valide ne doit pas produire
  une erreur serveur), et l'historique d'activité (séances, séries, records,
  mesures, journal alimentaire sans ses photos, conversations coach)
  rattaché à cet identifiant, qui ne porte plus rien qui identifie la
  personne. **Pour un temps seulement** : `dist/cli/deleted-accounts-purge`,
  que la supervision lance chaque jour (`scripts/server/_purge_comptes.sh`),
  efface DÉFINITIVEMENT les comptes supprimés depuis plus de
  `CARLYS_ACCOUNT_PURGE_DAYS` jours (30 par défaut) : leurs photos privées,
  puis la ligne `User` et, par cascade, tout ce qui s'y rattache, avec la
  trace brute des webhooks de paiement qui les nomment (retrouvés par
  `SubscriptionEvent.userId`, recopié à la réception, comme par
  l'abonnement). Un webhook qui nomme un compte supprimé, déjà effacé ou
  inconnu est acquitté sans être ni gardé ni appliqué — mais si le compte
  est SUPPRIMÉ et pas encore effacé (sa ligne existe, `deletedAt` posé) et
  que c'est un abonnement Stripe qui prélève encore, il est résilié à
  réception (`AccountBillingService.stopForAbsentAccount` : un paiement
  conclu juste avant la suppression, dont le webhook arrive juste après,
  échappait sinon à la résiliation ; un échec de Stripe répond 5xx, et
  Stripe réémet). Un compte inconnu ou déjà effacé ne déclenche AUCUNE
  résiliation : rien ne prouve que l'abonnement est le nôtre (sauvegarde
  restaurée, compte Stripe de test partagé), et elle est irréversible —, et
  un événement hors abonnement (facture, paiement) n'est jamais gardé : ni
  l'un ni l'autre ne laisse de charge utile en base. La passe quotidienne
  efface aussi les événements de paiement jamais appliqués qui ne nomment
  AUCUN compte (`processedAt` et `userId` nuls : achat RevenueCat anonyme,
  charge Stripe sans `metadata.userId`), reçus depuis plus de 90 jours
  (`ORPHAN_PAYMENT_EVENT_RETENTION_DAYS`) — la purge d'un compte ne les
  retrouvait jamais, et leur charge brute restait pour toujours ; un
  effacement ciblé (`--compte`) n'y touche pas. Le journal
  d'audit reste, `userId` mis à nul ; il ne porte pas l'adresse (un échec
  de connexion n'y laisse que `emailHash`), mais les actions du back-office
  gardent l'UUID de l'ancien compte dans `resourceId` (`<uuid>` ou
  `<uuid>:<droit>`) et le traitement d'un signalement dans
  `metadata.reporterId` : un identifiant qui, la ligne `User` partie, ne
  renvoie plus à rien. **Effacement immédiat sur demande écrite** :
  `--compte-actif <uuid> --confirmer <adresse>` traite un compte ENCORE
  ACTIF. Cette voie, et elle seule, démarre l'application : elle passe par
  `AccountService.deleteOnWrittenRequest`, donc par le MÊME
  `deleteVerified` que la route (résiliation Stripe, refus si elle échoue,
  retrait de la communauté), auditée `account.deleted_by_operator` (acteur
  `SYSTEM`, `requestId` `cli-…`), attend que la ligne d'audit soit écrite
  (elle nomme le compte), puis efface comme `--compte`. L'adresse recopiée
  (casse et espaces ignorés) doit être celle du compte, sinon code 2 et
  rien n'est fait ; `--a-blanc` dit ce qui serait fait. Cette recopie
  garde d'une faute de frappe sur l'UUID, pas d'une usurpation :
  l'expéditeur d'un courriel se falsifie, et aucun outil ne prouve qui
  demande. La procédure l'exige donc avant toute commande : un code tiré
  pour la demande, écrit dans un nouveau message à l'adresse du compte, et
  renvoyé par la personne. `carlysctl` demande l'adresse au clavier,
  jamais en argument, pour que l'historique du shell de root ne la garde
  pas. `--compte <uuid>`
  efface tout de suite un compte DÉJÀ supprimé ; comme la suppression
  réécrit l'adresse et efface nom et identités externes, plus rien ne mène
  alors de la personne à son UUID. La procédure
  (`docs/deployment/orchestration.md`, « Effacement immédiat sur demande »)
  relève donc l'UUID dans le back-office à réception de la demande, et la
  politique demande d'écrire AVANT de supprimer. Le délai de 30 jours est
  écrit en huit endroits, à changer
  ENSEMBLE avec `CARLYS_ACCOUNT_PURGE_DAYS` ou `DEFAULT_PURGE_DELAY_DAYS`
  (`users/application/deleted-accounts-purge.ts`) : `docs/legal/privacy.md`
  (sections 6 et 7), `docs/legal/terms.md` (section 9), l'écran de suppression
  (`account_deletion_summary.dart`), ce paragraphe,
  `docs/security/authentication.md` (encadré de statut),
  `docs/database/schema.md` (`User`), `README.md` (section sécurité) et
  `docs/deployment/orchestration.md` ; les commandes
  (`scripts/server/README.md`, `carlysctl`, `_purge_comptes.sh`) disent
  « 30 par défaut ». Aucun garde ne compare aujourd'hui ces textes à la
  valeur réglée sur le serveur.
- **Abonnement à la suppression — en place** : résilié chez Stripe avant
  toute suppression, refus 503 sinon (voir ci-dessus) ; un abonnement de
  magasin est signalé, pas résilié. La politique (section 6), les
  conditions d'utilisation (section 9) et l'écran de suppression le disent ;
  l'écran le rappelle après coup quand `storeSubscriptionStillActive` vaut
  `true`.
- **Rétention limitée des logs** applicatifs : cible, la durée reste « à
  compléter » dans la politique de confidentialité.
- **Chiffrement en transit** (TLS) sur tous les environnements distants.
- **Audit des accès administrateurs** (Étape 7 : rôles, permissions, journal
  d'audit) : en place.

---

## 4. Récapitulatif : en place vs cible

| Mesure | Statut |
| --- | --- |
| Secrets hors dépôt, `.env` ignorés, `.env.example` factices | En place |
| TruffleHog + `pnpm audit --audit-level high` en CI | En place |
| Config Zod bloquante au démarrage | En place |
| Validation `whitelist` + `forbidNonWhitelisted`, Helmet, CORS restreint | En place |
| Rate limiting 100 req/60 s, corps limité à 1 Mo (multipart : 5 Mio et `MEDIA_MAX_UPLOAD_BYTES`) | En place |
| Enveloppes d'erreur sans fuite (5xx génériques, sauf le 503 écrit pour la personne) | En place |
| `/metrics` protégé par Bearer token en production (comparaison temps constant) | En place |
| Logs Pino avec `requestId` (posé avant les parseurs de corps), `authorization`/`cookie` rédigés, adresses e-mail en empreinte (audit compris, anciennes lignes vidées), recherche du back-office dans le corps d'un `POST` | En place |
| Journal Nginx sans jetons de liens (accès masqué, erreurs écartées) | En place |
| Argon2id, JWT court, refresh rotatif hashé, détection de réutilisation | En place (Étape 2) |
| Verrouillage par compte réservé avant Argon2 (connexion, back-office, ré-authentification) | En place |
| Jetons push rattachés à la session, supprimés à sa révocation | En place |
| Catalogue en bucket public, photos de repas en bucket privé servies par l'API | En place |
| Webhooks signés idempotents, entitlements côté serveur | En place (Étape 6) |
| Rôles/permissions/audit admin | En place (Étape 7) |
| Suppression de compte : abonnement Stripe résilié d'abord, identité libérée et communauté quittée en une transaction, réinscription possible | En place |
| Purge différée des comptes supprimés (`deleted-accounts-purge`, quotidienne), événements de paiement anonymes effacés à 90 jours | En place |
| Effacement immédiat sur demande écrite, compte actif compris (`--compte-actif`), après un code renvoyé depuis l'adresse du compte | En place (preuve procédurale) |
| Sauvegardes nocturnes, avant migration, copie hors machine chiffrée | En place (copie distante dès sa configuration) |
| Consentement horodaté, export, rétention des logs | Cible |

---

*Document lié : `docs/security/authentication.md` (conception détaillée de
l'authentification).*
