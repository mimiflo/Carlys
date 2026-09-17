-- CreateEnum
CREATE TYPE "TrainingGoal" AS ENUM ('FAT_LOSS', 'MUSCLE_GAIN', 'RECOMPOSITION', 'HYROX', 'MARATHON', 'MAINTENANCE', 'STRENGTH', 'CALISTHENICS');

-- AlterTable
ALTER TABLE "UserProfile" ADD COLUMN     "trainingGoal" "TrainingGoal";
