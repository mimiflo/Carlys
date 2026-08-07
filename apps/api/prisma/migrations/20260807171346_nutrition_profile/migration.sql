-- CreateEnum
CREATE TYPE "BiologicalSex" AS ENUM ('MALE', 'FEMALE');

-- CreateEnum
CREATE TYPE "ActivityLevel" AS ENUM ('SEDENTARY', 'LIGHT', 'MODERATE', 'ACTIVE', 'VERY_ACTIVE');

-- CreateEnum
CREATE TYPE "NutritionGoal" AS ENUM ('LOSE_WEIGHT', 'MAINTAIN', 'GAIN_MUSCLE');

-- AlterTable
ALTER TABLE "UserProfile" ADD COLUMN     "activityLevel" "ActivityLevel",
ADD COLUMN     "birthDate" TIMESTAMP(3),
ADD COLUMN     "heightCm" DECIMAL(4,1),
ADD COLUMN     "nutritionGoal" "NutritionGoal",
ADD COLUMN     "sex" "BiologicalSex";
