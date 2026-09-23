-- Le mot du créateur d'un défi entre amis (facultatif, 280 caractères au
-- plus, validé à l'entrée), et ce qu'il faut pour le signaler : le défi visé
-- et les CLICHÉS de son titre et de son message, figés dans la transaction
-- du signalement comme l'est déjà le texte d'un encouragement. Aucune
-- reprise de données : aucun défi existant n'a de message, aucun
-- signalement existant ne vise un défi.

-- AlterTable
ALTER TABLE "CommunityReport" ADD COLUMN     "friendChallengeId" UUID,
ADD COLUMN     "friendChallengeMessage" TEXT,
ADD COLUMN     "friendChallengeTitle" TEXT;

-- AlterTable
ALTER TABLE "FriendChallenge" ADD COLUMN     "message" TEXT;

-- AddForeignKey
ALTER TABLE "CommunityReport" ADD CONSTRAINT "CommunityReport_friendChallengeId_fkey" FOREIGN KEY ("friendChallengeId") REFERENCES "FriendChallenge"("id") ON DELETE SET NULL ON UPDATE CASCADE;
