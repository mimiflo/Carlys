-- CreateEnum
CREATE TYPE "CoachMessageRole" AS ENUM ('USER', 'ASSISTANT');

-- CreateTable
CREATE TABLE "CoachConversation" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "title" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "CoachConversation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CoachMessage" (
    "id" UUID NOT NULL,
    "conversationId" UUID NOT NULL,
    "role" "CoachMessageRole" NOT NULL,
    "content" TEXT NOT NULL,
    "inputTokens" INTEGER,
    "outputTokens" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CoachMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CoachSessionProposal" (
    "id" UUID NOT NULL,
    "messageId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "estimatedMinutes" INTEGER NOT NULL,
    "sourceTemplateId" UUID,
    "acceptedSessionId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CoachSessionProposal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CoachSessionProposalItem" (
    "id" UUID NOT NULL,
    "proposalId" UUID NOT NULL,
    "exercisePosition" INTEGER NOT NULL,
    "exerciseId" UUID NOT NULL,
    "exerciseName" TEXT NOT NULL,
    "setPosition" INTEGER NOT NULL,
    "kind" "WorkoutSetKind" NOT NULL DEFAULT 'NORMAL',
    "targetReps" INTEGER,
    "targetWeightKg" DECIMAL(6,2),
    "restSeconds" INTEGER,

    CONSTRAINT "CoachSessionProposalItem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CoachConversation_userId_updatedAt_idx" ON "CoachConversation"("userId", "updatedAt" DESC);

-- CreateIndex
CREATE INDEX "CoachMessage_conversationId_createdAt_idx" ON "CoachMessage"("conversationId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "CoachSessionProposal_messageId_key" ON "CoachSessionProposal"("messageId");

-- CreateIndex
CREATE INDEX "CoachSessionProposalItem_proposalId_idx" ON "CoachSessionProposalItem"("proposalId");

-- CreateIndex
CREATE INDEX "CoachSessionProposalItem_exerciseId_idx" ON "CoachSessionProposalItem"("exerciseId");

-- CreateIndex
CREATE UNIQUE INDEX "CoachSessionProposalItem_proposalId_exercisePosition_setPos_key" ON "CoachSessionProposalItem"("proposalId", "exercisePosition", "setPosition");

-- AddForeignKey
ALTER TABLE "CoachConversation" ADD CONSTRAINT "CoachConversation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachMessage" ADD CONSTRAINT "CoachMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "CoachConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachSessionProposal" ADD CONSTRAINT "CoachSessionProposal_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "CoachMessage"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachSessionProposal" ADD CONSTRAINT "CoachSessionProposal_sourceTemplateId_fkey" FOREIGN KEY ("sourceTemplateId") REFERENCES "WorkoutTemplate"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachSessionProposalItem" ADD CONSTRAINT "CoachSessionProposalItem_proposalId_fkey" FOREIGN KEY ("proposalId") REFERENCES "CoachSessionProposal"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachSessionProposalItem" ADD CONSTRAINT "CoachSessionProposalItem_exerciseId_fkey" FOREIGN KEY ("exerciseId") REFERENCES "Exercise"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
