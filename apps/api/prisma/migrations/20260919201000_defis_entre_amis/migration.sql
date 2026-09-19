-- CreateEnum
CREATE TYPE "FriendChallengeStatus" AS ENUM ('OPEN', 'CLOSED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "FriendChallengeMemberStatus" AS ENUM ('INVITED', 'ACCEPTED', 'DECLINED', 'LEFT');

-- AlterEnum
ALTER TYPE "NotificationCategory" ADD VALUE 'CHALLENGE_INVITES';

-- CreateTable
CREATE TABLE "FriendChallenge" (
    "id" UUID NOT NULL,
    "creatorId" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "metric" "ChallengeMetric" NOT NULL,
    "target" INTEGER,
    "durationDays" INTEGER NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "status" "FriendChallengeStatus" NOT NULL DEFAULT 'OPEN',
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FriendChallenge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FriendChallengeMember" (
    "challengeId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "status" "FriendChallengeMemberStatus" NOT NULL DEFAULT 'INVITED',
    "invitedById" UUID NOT NULL,
    "contribution" INTEGER NOT NULL DEFAULT 0,
    "joinedAt" TIMESTAMP(3),
    "leftAt" TIMESTAMP(3),
    "finalRank" INTEGER,

    CONSTRAINT "FriendChallengeMember_pkey" PRIMARY KEY ("challengeId","userId")
);

-- CreateIndex
CREATE INDEX "FriendChallenge_creatorId_idx" ON "FriendChallenge"("creatorId");

-- CreateIndex
CREATE INDEX "FriendChallenge_status_endsAt_idx" ON "FriendChallenge"("status", "endsAt");

-- CreateIndex
CREATE INDEX "FriendChallengeMember_userId_status_idx" ON "FriendChallengeMember"("userId", "status");

-- AddForeignKey
ALTER TABLE "FriendChallenge" ADD CONSTRAINT "FriendChallenge_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FriendChallengeMember" ADD CONSTRAINT "FriendChallengeMember_challengeId_fkey" FOREIGN KEY ("challengeId") REFERENCES "FriendChallenge"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FriendChallengeMember" ADD CONSTRAINT "FriendChallengeMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
