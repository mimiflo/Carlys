-- AlterTable
ALTER TABLE "WorkoutSession" ADD COLUMN     "templateId" UUID,
ADD COLUMN     "templateName" TEXT;

-- AlterTable
ALTER TABLE "WorkoutSet" ADD COLUMN     "plannedReps" INTEGER,
ADD COLUMN     "plannedWeightKg" DECIMAL(6,2);

-- CreateTable
CREATE TABLE "WorkoutTemplate" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "notes" TEXT,
    "estimatedDurationMinutes" INTEGER,
    "lastUsedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "WorkoutTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkoutTemplateExercise" (
    "id" UUID NOT NULL,
    "templateId" UUID NOT NULL,
    "exerciseId" UUID,
    "exerciseName" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "notes" TEXT,

    CONSTRAINT "WorkoutTemplateExercise_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkoutTemplateSet" (
    "id" UUID NOT NULL,
    "templateExerciseId" UUID NOT NULL,
    "position" INTEGER NOT NULL,
    "kind" "WorkoutSetKind" NOT NULL DEFAULT 'NORMAL',
    "targetReps" INTEGER,
    "targetWeightKg" DECIMAL(6,2),
    "restSeconds" INTEGER,

    CONSTRAINT "WorkoutTemplateSet_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "WorkoutTemplate_userId_updatedAt_idx" ON "WorkoutTemplate"("userId", "updatedAt" DESC);

-- CreateIndex
CREATE INDEX "WorkoutTemplateExercise_exerciseId_idx" ON "WorkoutTemplateExercise"("exerciseId");

-- CreateIndex
CREATE UNIQUE INDEX "WorkoutTemplateExercise_templateId_position_key" ON "WorkoutTemplateExercise"("templateId", "position");

-- CreateIndex
CREATE UNIQUE INDEX "WorkoutTemplateSet_templateExerciseId_position_key" ON "WorkoutTemplateSet"("templateExerciseId", "position");

-- CreateIndex
CREATE INDEX "WorkoutSession_templateId_idx" ON "WorkoutSession"("templateId");

-- AddForeignKey
ALTER TABLE "WorkoutSession" ADD CONSTRAINT "WorkoutSession_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "WorkoutTemplate"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkoutTemplate" ADD CONSTRAINT "WorkoutTemplate_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkoutTemplateExercise" ADD CONSTRAINT "WorkoutTemplateExercise_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "WorkoutTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkoutTemplateExercise" ADD CONSTRAINT "WorkoutTemplateExercise_exerciseId_fkey" FOREIGN KEY ("exerciseId") REFERENCES "Exercise"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkoutTemplateSet" ADD CONSTRAINT "WorkoutTemplateSet_templateExerciseId_fkey" FOREIGN KEY ("templateExerciseId") REFERENCES "WorkoutTemplateExercise"("id") ON DELETE CASCADE ON UPDATE CASCADE;
