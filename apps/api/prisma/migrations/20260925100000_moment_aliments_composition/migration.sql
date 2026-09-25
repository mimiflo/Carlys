-- Repas : moment de la journée, base d'aliments CIQUAL, composition calculée.
--
-- Aucune donnée existante n'est réécrite : "moment" arrive nullable et sans
-- défaut (un repas ancien n'a jamais dit son moment), et les deux tables
-- naissent vides. La table "Food" se remplit par dist/cli/ciqual-import,
-- jamais par cette migration.

-- CreateEnum
CREATE TYPE "MealMoment" AS ENUM ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK');

-- AlterTable
ALTER TABLE "MealEntry" ADD COLUMN     "moment" "MealMoment";

-- CreateTable
CREATE TABLE "Food" (
    "code" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "shortName" TEXT NOT NULL,
    "groupCode" TEXT,
    "groupName" TEXT,
    "subgroupCode" TEXT,
    "subgroupName" TEXT,
    "kcalPer100g" DECIMAL(7,2) NOT NULL,
    "proteinPer100g" DECIMAL(7,2),
    "carbsPer100g" DECIMAL(7,2),
    "fatPer100g" DECIMAL(7,2),
    "searchKey" TEXT NOT NULL,
    "sourceVersion" TEXT NOT NULL,
    "retiredAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Food_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "MealComponent" (
    "id" UUID NOT NULL,
    "mealId" UUID NOT NULL,
    "foodCode" INTEGER NOT NULL,
    "position" INTEGER NOT NULL,
    "quantityG" DECIMAL(7,2) NOT NULL,
    "foodName" TEXT NOT NULL,
    "foodShortName" TEXT NOT NULL,
    "foodGroup" TEXT,
    "foodSourceVersion" TEXT NOT NULL,
    "kcalPer100g" DECIMAL(7,2) NOT NULL,
    "proteinPer100g" DECIMAL(7,2),
    "carbsPer100g" DECIMAL(7,2),
    "fatPer100g" DECIMAL(7,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MealComponent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "MealComponent_mealId_position_key" ON "MealComponent"("mealId", "position");

-- AddForeignKey
ALTER TABLE "MealComponent" ADD CONSTRAINT "MealComponent_mealId_fkey" FOREIGN KEY ("mealId") REFERENCES "MealEntry"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MealComponent" ADD CONSTRAINT "MealComponent_foodCode_fkey" FOREIGN KEY ("foodCode") REFERENCES "Food"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

