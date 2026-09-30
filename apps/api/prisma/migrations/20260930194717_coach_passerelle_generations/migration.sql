-- CreateEnum
CREATE TYPE "CoachGenerationStatus" AS ENUM ('QUEUED', 'PROCESSING', 'STREAMING', 'COMPLETED', 'FAILED', 'CANCELLED');

-- AlterTable
ALTER TABLE "CoachConversation" ADD COLUMN     "summary" TEXT,
ADD COLUMN     "summaryThrough" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "CoachGeneration" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "conversationId" UUID NOT NULL,
    "messageId" UUID NOT NULL,
    "status" "CoachGenerationStatus" NOT NULL DEFAULT 'QUEUED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "startedAt" TIMESTAMP(3),
    "firstTokenAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "inputTokens" INTEGER,
    "outputTokens" INTEGER,
    "model" TEXT,
    "worker" TEXT,
    "errorCode" TEXT,

    CONSTRAINT "CoachGeneration_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CoachGeneration_createdAt_idx" ON "CoachGeneration"("createdAt");

-- CreateIndex
CREATE INDEX "CoachGeneration_userId_createdAt_idx" ON "CoachGeneration"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "CoachGeneration" ADD CONSTRAINT "CoachGeneration_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
