-- AlterTable
ALTER TABLE "CoachMessage" ADD COLUMN     "createdTemplateId" UUID;

-- CreateIndex
CREATE INDEX "CoachMessage_createdTemplateId_idx" ON "CoachMessage"("createdTemplateId");

-- AddForeignKey
ALTER TABLE "CoachMessage" ADD CONSTRAINT "CoachMessage_createdTemplateId_fkey" FOREIGN KEY ("createdTemplateId") REFERENCES "WorkoutTemplate"("id") ON DELETE SET NULL ON UPDATE CASCADE;
