-- CreateTable
CREATE TABLE "WorkoutSessionPlanItem" (
    "id" UUID NOT NULL,
    "sessionId" UUID NOT NULL,
    "exercisePosition" INTEGER NOT NULL,
    "exerciseId" UUID,
    "exerciseName" TEXT NOT NULL,
    "setPosition" INTEGER NOT NULL,
    "kind" "WorkoutSetKind" NOT NULL DEFAULT 'NORMAL',
    "targetReps" INTEGER,
    "targetWeightKg" DECIMAL(6,2),
    "restSeconds" INTEGER,
    "doneSetId" UUID,
    "skipped" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WorkoutSessionPlanItem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "WorkoutSessionPlanItem_sessionId_idx" ON "WorkoutSessionPlanItem"("sessionId");

-- CreateIndex
CREATE INDEX "WorkoutSessionPlanItem_exerciseId_idx" ON "WorkoutSessionPlanItem"("exerciseId");

-- CreateIndex
CREATE UNIQUE INDEX "WorkoutSessionPlanItem_sessionId_exercisePosition_setPositi_key" ON "WorkoutSessionPlanItem"("sessionId", "exercisePosition", "setPosition");

-- AddForeignKey
ALTER TABLE "WorkoutSessionPlanItem" ADD CONSTRAINT "WorkoutSessionPlanItem_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "WorkoutSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkoutSessionPlanItem" ADD CONSTRAINT "WorkoutSessionPlanItem_exerciseId_fkey" FOREIGN KEY ("exerciseId") REFERENCES "Exercise"("id") ON DELETE SET NULL ON UPDATE CASCADE;
