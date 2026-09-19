-- CreateEnum
CREATE TYPE "MealQuantityUnit" AS ENUM ('GRAM', 'MILLILITER', 'PORTION', 'PIECE');

-- AlterTable
ALTER TABLE "MealEntry" ADD COLUMN     "quantity" DECIMAL(7,2),
ADD COLUMN     "quantityUnit" "MealQuantityUnit";
