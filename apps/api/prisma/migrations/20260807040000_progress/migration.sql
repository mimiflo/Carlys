-- CreateEnum
CREATE TYPE "PersonalRecordType" AS ENUM ('MAX_WEIGHT', 'MAX_REPS', 'MAX_SET_VOLUME');

-- CreateEnum
CREATE TYPE "BodyMetricType" AS ENUM ('WEIGHT_KG', 'BODY_FAT_PERCENT');

-- CreateTable
CREATE TABLE "PersonalRecord" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "exerciseId" UUID,
    "exerciseName" TEXT NOT NULL,
    "recordType" "PersonalRecordType" NOT NULL,
    "value" DECIMAL(10,2) NOT NULL,
    "reps" INTEGER,
    "weightKg" DECIMAL(6,2),
    "achievedAt" TIMESTAMP(3) NOT NULL,
    "sessionId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PersonalRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BodyMetric" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "metricType" "BodyMetricType" NOT NULL,
    "value" DECIMAL(6,2) NOT NULL,
    "measuredAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "BodyMetric_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PersonalRecord_userId_achievedAt_idx" ON "PersonalRecord"("userId", "achievedAt");

-- CreateIndex
CREATE UNIQUE INDEX "PersonalRecord_userId_exerciseName_recordType_key" ON "PersonalRecord"("userId", "exerciseName", "recordType");

-- CreateIndex
CREATE INDEX "BodyMetric_userId_metricType_measuredAt_idx" ON "BodyMetric"("userId", "metricType", "measuredAt");

-- AddForeignKey
ALTER TABLE "PersonalRecord" ADD CONSTRAINT "PersonalRecord_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PersonalRecord" ADD CONSTRAINT "PersonalRecord_exerciseId_fkey" FOREIGN KEY ("exerciseId") REFERENCES "Exercise"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PersonalRecord" ADD CONSTRAINT "PersonalRecord_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "WorkoutSession"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BodyMetric" ADD CONSTRAINT "BodyMetric_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

