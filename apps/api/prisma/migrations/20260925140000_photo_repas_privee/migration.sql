-- Photo d'un repas, PRIVÉE : la ligne décrit l'objet stocké dans le bucket
-- privé (S3_PRIVATE_BUCKET), jamais dans le bucket public des médias.
--
-- Une ligne par repas au plus (clé primaire = le repas), supprimée avec lui
-- (ON DELETE CASCADE). La table naît vide : aucune donnée existante n'est
-- touchée.

-- CreateTable
CREATE TABLE "MealPhoto" (
    "mealId" UUID NOT NULL,
    "storageKey" TEXT NOT NULL,
    "byteSize" INTEGER NOT NULL,
    "sha256" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MealPhoto_pkey" PRIMARY KEY ("mealId")
);

-- CreateIndex
CREATE UNIQUE INDEX "MealPhoto_storageKey_key" ON "MealPhoto"("storageKey");

-- AddForeignKey
ALTER TABLE "MealPhoto" ADD CONSTRAINT "MealPhoto_mealId_fkey" FOREIGN KEY ("mealId") REFERENCES "MealEntry"("id") ON DELETE CASCADE ON UPDATE CASCADE;
