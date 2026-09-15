-- Index du journal d'audit : alignés sur les requêtes qui existent VRAIMENT.
--
-- Ce qu'il manquait. La seule lecture de la table (`listAuditLogs`) pagine
-- SANS aucun filtre — le DTO ne porte que `limit` et `cursor` — et trie par
-- `("createdAt" DESC, "id" DESC)`. Aucun des trois index d'origine ne
-- commençait par `createdAt` : PostgreSQL n'en tirait donc rien, et chaque
-- page du back-office balayait puis triait une table append-only, jamais
-- purgée, alimentée à chaque connexion, chaque rafraîchissement et chaque
-- action d'administration. C'est la règle que le dépôt s'est lui-même donnée
-- (docs/database/schema.md) : « chaque liste s'appuie sur un index composite
-- couvrant l'ordre de tri, se terminant par `id` pour départager les
-- ex-aequo ».
--
-- Ce qui part. `action` et `(resourceType, resourceId)` n'ont AUCUN lecteur :
-- aucun filtre au contrat, aucun au contrôleur, aucune requête nulle part.
-- Un index qui ne sert aucune requête n'est pas neutre — il se paie à chaque
-- écriture, sur une table qui grossit à chaque connexion. Ils reviendront
-- avec les filtres qui les justifieront, en une ligne.
--
-- Ce qui RESTE, et pourquoi. `(userId, createdAt)` a bien un usage, moins
-- visible : la relation est `onDelete: SetNull`, donc supprimer un compte
-- exécute `UPDATE "AuditLog" SET "userId" = NULL WHERE "userId" = $1`.
-- L'effacement d'un compte est un droit, pas une option : sans cet index il
-- balaierait tout le journal. Pour la même raison, `adminUserId` — également
-- en `onDelete: SetNull` — reçoit enfin le sien, qui manquait.
--
-- Migration écrite à la main, alignée sur les conventions Prisma.

-- CreateIndex
CREATE INDEX "AuditLog_createdAt_id_idx" ON "AuditLog"("createdAt", "id");

-- CreateIndex
CREATE INDEX "AuditLog_adminUserId_idx" ON "AuditLog"("adminUserId");

-- DropIndex
DROP INDEX "AuditLog_action_createdAt_idx";

-- DropIndex
DROP INDEX "AuditLog_resourceType_resourceId_createdAt_idx";
