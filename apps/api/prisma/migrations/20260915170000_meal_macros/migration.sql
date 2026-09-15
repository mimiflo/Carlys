-- Glucides et lipides sur une entrée de journal.
--
-- Nullables et sans valeur par défaut : une entrée déjà enregistrée ne
-- connaît pas ses glucides, et lui poser un 0 la ferait mentir. `null` veut
-- dire « on ne sait pas » ; l'écran doit pouvoir faire la différence.
ALTER TABLE "MealEntry" ADD COLUMN "carbsG" INTEGER;
ALTER TABLE "MealEntry" ADD COLUMN "fatG" INTEGER;
