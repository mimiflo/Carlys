-- Trois index en DOUBLE, payés à chaque écriture : chacun n'est qu'un préfixe
-- d'une clé qui existe déjà et sert les mêmes lectures (PostgreSQL parcourt
-- un index B-tree dans les deux sens).
--   LeagueMembership (userId, periodKey DESC) : la clé primaire (userId, periodKey).
--   WorkoutSessionPlanItem (sessionId) : l'unique (sessionId, exercisePosition, setPosition).
--   CoachSessionProposalItem (proposalId) : l'unique (proposalId, exercisePosition, setPosition).
DROP INDEX "LeagueMembership_userId_periodKey_idx";
DROP INDEX "WorkoutSessionPlanItem_sessionId_idx";
DROP INDEX "CoachSessionProposalItem_proposalId_idx";

-- La liste des comptes du back-office trie par (createdAt DESC, id DESC).
CREATE INDEX "User_createdAt_id_idx" ON "User"("createdAt", "id");
