-- AlterTable
ALTER TABLE "Program" ADD COLUMN     "generationReport" JSONB;

-- AlterTable
ALTER TABLE "WorkoutTemplate" ADD COLUMN     "generatedFromProgramId" UUID;

-- CreateIndex
CREATE INDEX "WorkoutTemplate_generatedFromProgramId_idx" ON "WorkoutTemplate"("generatedFromProgramId");
