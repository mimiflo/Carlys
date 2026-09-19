-- L'unité réellement comptée par un défi.
--
-- Écrite À LA MAIN plutôt que générée : `ADD COLUMN … NOT NULL` sans défaut
-- échoue sur une table peuplée, et un défaut arbitraire mentirait sur les
-- défis déjà en base. La colonne arrive donc nullable, se remplit depuis
-- `kind` — ce que ces défis comptaient vraiment — puis devient obligatoire.
CREATE TYPE "ChallengeMetric" AS ENUM ('WORKOUTS', 'QUIZ_CORRECT', 'ACTIVE_SECONDS', 'DISTANCE_METERS');

ALTER TABLE "CommunityChallenge" ADD COLUMN "metric" "ChallengeMetric";

UPDATE "CommunityChallenge"
SET "metric" = CASE "kind"
  WHEN 'CULTURE' THEN 'QUIZ_CORRECT'::"ChallengeMetric"
  ELSE 'WORKOUTS'::"ChallengeMetric"
END;

ALTER TABLE "CommunityChallenge" ALTER COLUMN "metric" SET NOT NULL;
