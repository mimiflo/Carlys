-- Un index pour chaque clé étrangère que l'EFFACEMENT D'UN COMPTE traverse.
--
-- Supprimer une ligne oblige PostgreSQL à retrouver, dans chaque table qui la
-- référence, les lignes à effacer (CASCADE) ou à vider (SET NULL). Sans index
-- sur la colonne référençante, chaque recherche balaie TOUTE la table, et elle
-- se répète pour CHAQUE ligne supprimée. La purge des comptes supprimés
-- (`deleted-accounts-purge`) efface un compte d'un seul geste, en transaction :
-- mesuré avant cette migration, un compte de 300 séances à côté de 200 000
-- records mettait 7,3 s (un balayage de "PersonalRecord" par séance, pour le
-- SET NULL de "sessionId"), dépassait le délai de la transaction, et le compte
-- n'était jamais effacé. Avec l'index : quelques dizaines de millisecondes.
--
-- Les sept autres suivent la même règle, que `test/purge-index.e2e-spec.ts`
-- vérifie sur le catalogue de la base migrée : toute clé qui vise une table
-- atteinte par la cascade depuis "User" a un index qui commence par ses
-- colonnes. Deux d'entre elles se répètent aussi par ligne supprimée
-- (propositions du coach par modèle, signalements par encouragement) ; les
-- autres coûtent un balayage par compte ou par abonnement. Toutes portent sur
-- des tables à écriture rare, sauf "Encouragement", qui gagne un index sur une
-- colonne déjà lue.
--
-- Migration écrite à la main, alignée sur les conventions Prisma.

-- CreateIndex
CREATE INDEX "CoachSessionProposal_sourceTemplateId_idx" ON "CoachSessionProposal"("sourceTemplateId");

-- CreateIndex
CREATE INDEX "CommunityReport_reporterId_idx" ON "CommunityReport"("reporterId");

-- CreateIndex
CREATE INDEX "CommunityReport_encouragementId_idx" ON "CommunityReport"("encouragementId");

-- CreateIndex
CREATE INDEX "CommunityReport_friendChallengeId_idx" ON "CommunityReport"("friendChallengeId");

-- CreateIndex
CREATE INDEX "Encouragement_senderId_idx" ON "Encouragement"("senderId");

-- CreateIndex
CREATE INDEX "PersonalRecord_sessionId_idx" ON "PersonalRecord"("sessionId");

-- CreateIndex
CREATE INDEX "SubscriptionEvent_subscriptionId_idx" ON "SubscriptionEvent"("subscriptionId");

-- CreateIndex
CREATE INDEX "UserEntitlement_sourceSubscriptionId_idx" ON "UserEntitlement"("sourceSubscriptionId");
