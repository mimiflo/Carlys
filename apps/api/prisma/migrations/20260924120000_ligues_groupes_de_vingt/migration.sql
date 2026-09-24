-- Les ligues se jouent par GROUPES de 20 au sein d'une division et d'une
-- période : `cohort` numérote le groupe de (periodKey, division). Le
-- classement, le règlement et la zone de montée se lisent désormais par
-- groupe ; l'index du classement gagne donc la colonne entre la division et
-- le score (il sert aussi le remplissage, qui compte les membres par groupe).
--
-- Aucune reprise de données : les lignes existantes gardent le groupe 0 (le
-- défaut), c'est-à-dire exactement le classement qu'elles avaient — toute la
-- division. Une période déjà ouverte au-delà de 20 membres se finit telle
-- quelle ; seules les ouvertures suivantes remplissent des groupes de 20.

-- DropIndex
DROP INDEX "LeagueMembership_periodKey_division_score_idx";

-- AlterTable
ALTER TABLE "LeagueMembership" ADD COLUMN     "cohort" INTEGER NOT NULL DEFAULT 0;

-- CreateIndex
CREATE INDEX "LeagueMembership_periodKey_division_cohort_score_idx" ON "LeagueMembership"("periodKey", "division", "cohort", "score" DESC);
