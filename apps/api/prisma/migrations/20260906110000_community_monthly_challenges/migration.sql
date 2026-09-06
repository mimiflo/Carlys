-- Défis du mois : le jeu est créé paresseusement depuis le catalogue en code,
-- unique par (slug, mois). Les défis existants prennent le mois de leur début.
-- Migration écrite à la main, alignée sur les conventions Prisma.

-- AlterTable
ALTER TABLE "CommunityChallenge" ADD COLUMN "month" TEXT;

-- Les lignes déjà présentes (seed de développement) reçoivent leur mois.
UPDATE "CommunityChallenge" SET "month" = to_char("startsAt", 'YYYY-MM') WHERE "month" IS NULL;

-- AlterTable
ALTER TABLE "CommunityChallenge" ALTER COLUMN "month" SET NOT NULL;

-- DropIndex
DROP INDEX "CommunityChallenge_slug_key";

-- CreateIndex
CREATE UNIQUE INDEX "CommunityChallenge_slug_month_key" ON "CommunityChallenge"("slug", "month");

-- CreateIndex
CREATE INDEX "CommunityChallenge_month_idx" ON "CommunityChallenge"("month");
