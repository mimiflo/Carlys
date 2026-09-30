-- CreateTable
CREATE TABLE "CoachProgramProposal" (
    "id" UUID NOT NULL,
    "messageId" UUID NOT NULL,
    "goal" "TrainingGoal" NOT NULL,
    "weeklySessions" INTEGER NOT NULL,
    "sessionMinutes" INTEGER NOT NULL,
    "acceptedProgramId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CoachProgramProposal_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CoachProgramProposal_messageId_key" ON "CoachProgramProposal"("messageId");

-- AddForeignKey
ALTER TABLE "CoachProgramProposal" ADD CONSTRAINT "CoachProgramProposal_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "CoachMessage"("id") ON DELETE CASCADE ON UPDATE CASCADE;
