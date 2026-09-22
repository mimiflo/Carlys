-- CreateEnum
CREATE TYPE "MilestoneKind" AS ENUM ('RECORD', 'REWARD', 'TITLE');

-- CreateTable
CREATE TABLE "ProgressMilestone" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "kind" "MilestoneKind" NOT NULL,
    "key" TEXT NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "payload" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProgressMilestone_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ProgressMilestone_userId_occurredAt_idx" ON "ProgressMilestone"("userId", "occurredAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "ProgressMilestone_userId_kind_key_key" ON "ProgressMilestone"("userId", "kind", "key");

-- AddForeignKey
ALTER TABLE "ProgressMilestone" ADD CONSTRAINT "ProgressMilestone_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
