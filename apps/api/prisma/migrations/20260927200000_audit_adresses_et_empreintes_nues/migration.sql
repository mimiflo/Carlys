-- Rétention du journal d'audit : ce que les anciennes lignes gardaient sans
-- protection en sort (décision du 27 septembre 2026).
--
-- Depuis 7921f3f (27 septembre 2026, 17:23:27 UTC), l'audit d'un échec de
-- connexion, mobile comme back-office (`auth.login_failed`,
-- `auth.login_blocked_lockout`, `admin.login_failed`,
-- `admin.login_blocked_lockout`), ne garde de l'adresse saisie qu'une
-- empreinte À CLÉ : `metadata.emailHash`, un HMAC-SHA-256 tronqué à
-- 12 caractères hexadécimaux (`common/utilities/log-privacy.ts`). Les lignes
-- plus anciennes n'ont pas été réécrites.
--
-- 1. ADRESSES EN CLAIR (`metadata.email`) → `emailHash: null`.
--
--    L'empreinte actuelle N'EST PAS calculable ici. Sa clé est dérivée par
--    HKDF de `JWT_ACCESS_SECRET` (`AppConfigService.logFingerprintKey`), qui
--    ne vit que dans l'environnement du serveur : ni la base ni cette
--    migration ne la connaissent, et l'y écrire publierait un secret dans le
--    dépôt. (PostgreSQL saurait calculer un HMAC — `sha256()` est intégré —,
--    c'est la clé qui manque.) L'adresse est donc remplacée par une empreinte
--    NULLE : la ligne garde sa forme actuelle, et dit qu'une adresse était
--    là sans plus dire laquelle. La corrélation de ces anciens échecs entre
--    eux est perdue ; c'est le prix d'une adresse qu'on ne garde plus.
--
--    L'historique du dépôt montre que le MOBILE écrivait lui aussi l'adresse
--    en clair avant 7921f3f, pas seulement le back-office : toute ligne qui
--    porte `metadata.email` est traitée, quelle que soit son action.
--
-- 2. EMPREINTES SANS CLÉ (SHA-256 nu) → `emailHash: null`.
--
--    Un SHA-256 nu, même tronqué à 48 bits, se renverse par dictionnaire :
--    il ne protège rien. Rien dans l'historique du dépôt n'en a écrit dans
--    l'audit, mais une empreinte nue ne se distingue d'un HMAC ni par sa
--    forme ni par sa valeur ; deux critères sûrs la désignent : une
--    `emailHash` écrite AVANT l'existence du code HMAC (elle ne peut pas en
--    être un), ou qui n'a pas la forme de celles qu'il écrit (12 caractères
--    hexadécimaux).
--
-- Idempotente : une fois passée, plus aucune ligne ne répond aux conditions.
-- Un seul parcours du journal, une fois, au déploiement.

UPDATE "AuditLog"
SET "metadata" = ("metadata" - 'email') || jsonb_build_object('emailHash', NULL)
WHERE "metadata" ? 'email';

UPDATE "AuditLog"
SET "metadata" = jsonb_set("metadata", '{emailHash}', 'null'::jsonb)
WHERE jsonb_typeof("metadata" -> 'emailHash') = 'string'
  AND (
    "createdAt" < TIMESTAMP '2026-09-27 17:23:27'
    OR ("metadata" ->> 'emailHash') !~ '^[0-9a-f]{12}$'
  );
