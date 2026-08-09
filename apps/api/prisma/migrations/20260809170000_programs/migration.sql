-- Programmes multi-semaines : un plan dans le TEMPS, pas un contenu de
-- séance. Chaque jour pointe vers un modèle existant (ON DELETE SET NULL :
-- supprimer un modèle vide la case, il ne fait pas disparaître le plan) ou
-- ne porte qu'un intitulé — repos, activité libre.

-- CreateTable
CREATE TABLE "Program" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "weeksCount" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Program_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProgramDay" (
    "id" UUID NOT NULL,
    "programId" UUID NOT NULL,
    "weekNumber" INTEGER NOT NULL,
    "dayOfWeek" INTEGER NOT NULL,
    "templateId" UUID,
    "label" TEXT NOT NULL,
    "isRest" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "ProgramDay_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Program_userId_updatedAt_idx" ON "Program"("userId", "updatedAt" DESC);

-- CreateIndex
CREATE INDEX "ProgramDay_templateId_idx" ON "ProgramDay"("templateId");

-- CreateIndex
CREATE UNIQUE INDEX "ProgramDay_programId_weekNumber_dayOfWeek_key" ON "ProgramDay"("programId", "weekNumber", "dayOfWeek");

-- AddForeignKey
ALTER TABLE "Program" ADD CONSTRAINT "Program_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProgramDay" ADD CONSTRAINT "ProgramDay_programId_fkey" FOREIGN KEY ("programId") REFERENCES "Program"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProgramDay" ADD CONSTRAINT "ProgramDay_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "WorkoutTemplate"("id") ON DELETE SET NULL ON UPDATE CASCADE;

