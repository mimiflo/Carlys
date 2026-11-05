-- Effort perçu de la séance entière (échelle de Borg CR10), déclaré au bilan.
--
-- Colonne nullable, sans valeur par défaut : les séances existantes restent
-- intactes et « non évaluées », ce qui est exact. La borne 1..10 est posée
-- EN BASE aussi, pas seulement dans le DTO : aucune écriture, d'où qu'elle
-- vienne, n'y range une valeur hors échelle.
--
-- L'écrire passe par un UPDATE de la séance : le déclencheur
-- `WorkoutSession_revision` (migration 20260927400000) fait donc monter la
-- révision, et un autre appareil la rapatrie sans rien de plus.
ALTER TABLE "WorkoutSession" ADD COLUMN "perceivedEffort" INTEGER;

ALTER TABLE "WorkoutSession"
  ADD CONSTRAINT "WorkoutSession_perceivedEffort_check"
  CHECK ("perceivedEffort" BETWEEN 1 AND 10);
