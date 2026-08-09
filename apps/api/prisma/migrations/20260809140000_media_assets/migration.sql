-- Bibliothèque de médias : tout fichier servi par l'application entre par
-- l'administration et vit dans le stockage objet. Photo d'exercice et maillage
-- 3D suivent le MÊME chemin et ne se distinguent que par `kind`.

-- CreateEnum
CREATE TYPE "MediaKind" AS ENUM ('IMAGE', 'MESH_3D', 'VIDEO');

-- CreateTable
CREATE TABLE "MediaAsset" (
    "id" UUID NOT NULL,
    "kind" "MediaKind" NOT NULL,
    "storageKey" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "byteSize" INTEGER NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    "checksum" TEXT NOT NULL,
    "originalName" TEXT NOT NULL,
    "uploadedById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "MediaAsset_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "MediaAsset_storageKey_key" ON "MediaAsset"("storageKey");

-- CreateIndex
CREATE INDEX "MediaAsset_kind_createdAt_idx" ON "MediaAsset"("kind", "createdAt");

-- CreateIndex
CREATE INDEX "MediaAsset_checksum_idx" ON "MediaAsset"("checksum");

-- AlterTable : rattachements de l'exercice, un par rôle.
ALTER TABLE "Exercise" ADD COLUMN     "imageId" UUID,
ADD COLUMN     "meshId" UUID;

-- AddForeignKey
ALTER TABLE "MediaAsset" ADD CONSTRAINT "MediaAsset_uploadedById_fkey" FOREIGN KEY ("uploadedById") REFERENCES "AdminUser"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey : SetNull et non Cascade — supprimer un média ne supprime
-- jamais un exercice, il le laisse sans photo.
ALTER TABLE "Exercise" ADD CONSTRAINT "Exercise_imageId_fkey" FOREIGN KEY ("imageId") REFERENCES "MediaAsset"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Exercise" ADD CONSTRAINT "Exercise_meshId_fkey" FOREIGN KEY ("meshId") REFERENCES "MediaAsset"("id") ON DELETE SET NULL ON UPDATE CASCADE;
