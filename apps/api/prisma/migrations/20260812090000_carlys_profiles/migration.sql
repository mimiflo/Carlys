-- Les 4 profils Carlys : une identité d'usage choisie par la personne,
-- jamais un niveau. Migration écrite à la main, conventions Prisma.

-- CreateEnum
CREATE TYPE "CarlysProfile" AS ENUM ('CONSTRUCTEUR', 'CHALLENGER', 'ATHLETE', 'STRATEGE');

-- AlterTable
ALTER TABLE "UserProfile" ADD COLUMN "carlysProfile" "CarlysProfile";
