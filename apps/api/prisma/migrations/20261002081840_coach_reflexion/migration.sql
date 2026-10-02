-- AlterTable
ALTER TABLE "CoachMessage" ADD COLUMN     "steps" TEXT[] DEFAULT ARRAY[]::TEXT[];
