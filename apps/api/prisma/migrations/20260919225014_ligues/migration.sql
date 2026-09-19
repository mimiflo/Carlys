-- CreateEnum
CREATE TYPE "LeagueDivision" AS ENUM ('BRONZE', 'ARGENT', 'OR', 'PLATINE', 'DIAMANT');

-- AlterTable
ALTER TABLE "CommunityPreference" ADD COLUMN     "joinsLeague" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "LeagueMembership" (
    "userId" UUID NOT NULL,
    "periodKey" TEXT NOT NULL,
    "division" "LeagueDivision" NOT NULL,
    "score" INTEGER NOT NULL DEFAULT 0,
    "finalRank" INTEGER,
    "nextDivision" "LeagueDivision",
    "settledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LeagueMembership_pkey" PRIMARY KEY ("userId","periodKey")
);

-- CreateIndex
CREATE INDEX "LeagueMembership_periodKey_division_score_idx" ON "LeagueMembership"("periodKey", "division", "score" DESC);

-- CreateIndex
CREATE INDEX "LeagueMembership_userId_periodKey_idx" ON "LeagueMembership"("userId", "periodKey" DESC);

-- AddForeignKey
ALTER TABLE "LeagueMembership" ADD CONSTRAINT "LeagueMembership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
