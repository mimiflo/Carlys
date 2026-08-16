-- Préférences de notification, par catégorie.
--
-- Absence de ligne = accepté : le réglage n'existe que pour ce qui a été
-- explicitement refusé, et une catégorie ajoutée plus tard n'arrive donc pas
-- coupée pour tout le monde. La coupure est respectée à l'ENVOI, côté
-- serveur : une préférence que seul le téléphone connaîtrait laisserait la
-- notification arriver quand même.
--
-- Migration écrite à la main, alignée sur les conventions Prisma.

-- CreateEnum
CREATE TYPE "NotificationCategory" AS ENUM ('FRIEND_REQUESTS', 'ENCOURAGEMENTS');

-- CreateTable
CREATE TABLE "NotificationPreference" (
    "userId" UUID NOT NULL,
    "category" "NotificationCategory" NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationPreference_pkey" PRIMARY KEY ("userId","category")
);

-- AddForeignKey
ALTER TABLE "NotificationPreference" ADD CONSTRAINT "NotificationPreference_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
