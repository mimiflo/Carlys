-- AlterTable
ALTER TABLE "Program" ADD COLUMN     "startsOn" DATE;

-- AlterTable
ALTER TABLE "WorkoutSession" ADD COLUMN     "programDayId" UUID;

-- CreateIndex
CREATE INDEX "WorkoutSession_programDayId_idx" ON "WorkoutSession"("programDayId");
