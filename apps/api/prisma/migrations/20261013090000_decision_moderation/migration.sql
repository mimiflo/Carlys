-- Décision de modération sur un signalement : qui l'a prise, sa note, et ce
-- qu'elle a fait (contenu retiré, personne suspendue). Colonnes nullables ou
-- à défaut constant : ajout sans réécriture de table, les signalements
-- existants restent des résolutions « sans décision » (drapeaux à false).
-- Le mot d'un défi retiré par la modération se date dans `messageRemovedAt`.

-- AlterTable
ALTER TABLE "CommunityReport" ADD COLUMN     "contentRemoved" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "resolutionNote" TEXT,
ADD COLUMN     "resolvedByAdminId" UUID,
ADD COLUMN     "userSuspended" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "FriendChallenge" ADD COLUMN     "messageRemovedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "CommunityReport_resolvedByAdminId_idx" ON "CommunityReport"("resolvedByAdminId");

-- AddForeignKey
ALTER TABLE "CommunityReport" ADD CONSTRAINT "CommunityReport_resolvedByAdminId_fkey" FOREIGN KEY ("resolvedByAdminId") REFERENCES "AdminUser"("id") ON DELETE SET NULL ON UPDATE CASCADE;

