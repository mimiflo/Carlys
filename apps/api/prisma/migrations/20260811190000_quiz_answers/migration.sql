-- Réponses aux quiz de l'Academy : la source des défis CULTURE.
-- Migration écrite à la main, alignée sur les conventions Prisma.

-- CreateTable
CREATE TABLE "QuizAnswer" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "lessonId" TEXT NOT NULL,
    "answeredOn" TEXT NOT NULL,
    "correct" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "QuizAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "QuizAnswer_userId_lessonId_answeredOn_key" ON "QuizAnswer"("userId", "lessonId", "answeredOn");

-- CreateIndex
CREATE INDEX "QuizAnswer_userId_createdAt_idx" ON "QuizAnswer"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "QuizAnswer" ADD CONSTRAINT "QuizAnswer_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
