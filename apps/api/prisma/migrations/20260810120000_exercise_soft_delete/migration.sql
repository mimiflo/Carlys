-- Suppression DOUCE d'un exercice, depuis l'administration.
--
-- Un exercice est cité par des séries déjà réalisées, des records personnels
-- et des modèles de séance : un vrai DELETE effacerait — ou trouerait —
-- l'historique d'utilisateurs qui n'ont rien demandé. La colonne marque la
-- date de retrait ; le service force en même temps `isPublished` à faux, ce
-- qui suffit à faire disparaître l'exercice de tout le reste du code, qui
-- filtre déjà sur ce drapeau.
ALTER TABLE "Exercise" ADD COLUMN     "deletedAt" TIMESTAMP(3);

-- L'administration liste par défaut les exercices VIVANTS : l'index sert ce
-- filtre, présent sur chaque page du back-office.
CREATE INDEX "Exercise_deletedAt_idx" ON "Exercise"("deletedAt");
