-- Cliché du texte d'un encouragement signalé : l'auteur peut retirer son
-- message (DELETE /community/encouragements/:id) et la référence passe à
-- NULL, mais l'administration doit encore pouvoir lire ce qui a été signalé.
-- Migration écrite à la main, alignée sur les conventions Prisma.

-- AlterTable
ALTER TABLE "CommunityReport" ADD COLUMN "encouragementMessage" TEXT;

-- Les signalements déjà posés dont le message existe encore reçoivent leur
-- cliché maintenant ; ceux dont le message a déjà disparu restent sans texte,
-- il n'y a plus rien à figer.
UPDATE "CommunityReport" AS report
SET "encouragementMessage" = encouragement."message"
FROM "Encouragement" AS encouragement
WHERE report."encouragementId" = encouragement."id"
  AND report."encouragementMessage" IS NULL;
