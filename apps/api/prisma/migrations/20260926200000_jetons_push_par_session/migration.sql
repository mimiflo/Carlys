-- Un jeton push appartient à la SESSION qui l'a enregistré : révoquer la
-- session le supprime (voir le modèle DeviceToken). Les jetons existants
-- restent sans session (`NULL`) ; ils tombent à la première révocation qui
-- touche le compte, et l'appareil les réenregistre, rattachés, à son
-- prochain démarrage.

-- AlterTable
ALTER TABLE "DeviceToken" ADD COLUMN     "sessionId" UUID;

-- CreateIndex
CREATE INDEX "DeviceToken_sessionId_idx" ON "DeviceToken"("sessionId");

-- AddForeignKey
ALTER TABLE "DeviceToken" ADD CONSTRAINT "DeviceToken_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "UserSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;
