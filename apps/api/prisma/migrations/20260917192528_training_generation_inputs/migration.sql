-- CreateEnum
CREATE TYPE "TrainingExperience" AS ENUM ('BEGINNER', 'INTERMEDIATE', 'ADVANCED');

-- AlterTable
ALTER TABLE "UserProfile" ADD COLUMN     "sessionMinutesTarget" INTEGER,
ADD COLUMN     "trainingExperience" "TrainingExperience",
ADD COLUMN     "weeklySessionsTarget" INTEGER;

-- CreateTable
CREATE TABLE "UserEquipment" (
    "userId" UUID NOT NULL,
    "equipmentId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserEquipment_pkey" PRIMARY KEY ("userId","equipmentId")
);

-- CreateIndex
CREATE INDEX "UserEquipment_equipmentId_idx" ON "UserEquipment"("equipmentId");

-- AddForeignKey
ALTER TABLE "UserEquipment" ADD CONSTRAINT "UserEquipment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserEquipment" ADD CONSTRAINT "UserEquipment_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;
