-- Une contribution versée appartient à l'objectif COLLECTIF.
-- Quitter un défi effaçait la ligne de participation : la somme affichée à
-- tous les autres participants redescendait d'autant, alors qu'un compteur
-- collectif ne peut que monter. La ligne survit désormais au départ.
ALTER TABLE "ChallengeParticipation" ADD COLUMN "leftAt" TIMESTAMP(3);

-- Une amitié n'a pas de sens, la base doit la voir comme une PAIRE.
-- `@@unique([requesterId, addresseeId])` est dirigée : deux personnes qui se
-- demandaient en même temps créaient deux lignes pour la même paire, et
-- accepter l'une laissait l'autre en attente pour toujours.
ALTER TABLE "Friendship" ADD COLUMN "userLowId" UUID;
ALTER TABLE "Friendship" ADD COLUMN "userHighId" UUID;

UPDATE "Friendship"
SET "userLowId" = LEAST("requesterId", "addresseeId"),
    "userHighId" = GREATEST("requesterId", "addresseeId");

-- Les paires en double que l'ancienne unicité laissait passer : on garde la
-- ligne la plus avancée (amitié > demande en attente > refus), puis la plus
-- récente. Sans ce ménage, l'index unique ci-dessous refuserait de se créer.
DELETE FROM "Friendship" f
USING "Friendship" g
WHERE f."userLowId" = g."userLowId"
  AND f."userHighId" = g."userHighId"
  AND f."id" <> g."id"
  AND (
    CASE g."status" WHEN 'ACCEPTED' THEN 2 WHEN 'PENDING' THEN 1 ELSE 0 END,
    g."createdAt",
    g."id"
  ) > (
    CASE f."status" WHEN 'ACCEPTED' THEN 2 WHEN 'PENDING' THEN 1 ELSE 0 END,
    f."createdAt",
    f."id"
  );

ALTER TABLE "Friendship" ALTER COLUMN "userLowId" SET NOT NULL;
ALTER TABLE "Friendship" ALTER COLUMN "userHighId" SET NOT NULL;

DROP INDEX "Friendship_requesterId_addresseeId_key";

CREATE UNIQUE INDEX "Friendship_userLowId_userHighId_key"
  ON "Friendship"("userLowId", "userHighId");
