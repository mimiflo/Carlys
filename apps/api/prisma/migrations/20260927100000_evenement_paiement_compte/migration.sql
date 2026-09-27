-- Le compte que nomme un événement de paiement, recopié à la réception.
--
-- La purge des comptes supprimés n'effaçait que les événements RATTACHÉS à un
-- abonnement du compte. Ceux dont la projection avait échoué (subscriptionId
-- nul) gardaient leur charge utile brute — identifiant du compte, attributs de
-- l'abonné — au-delà de l'effacement, sans échéance. La purge les retrouve
-- désormais par cette colonne, indexée, sans parcourir le JSON.

-- AlterTable
ALTER TABLE "SubscriptionEvent" ADD COLUMN     "userId" UUID;

-- Reprise de l'existant : d'abord par l'abonnement rattaché, puis par la
-- charge utile elle-même (même extraction qu'à l'ingestion). Le filtre
-- d'UUID écarte toute valeur que la conversion refuserait.
UPDATE "SubscriptionEvent" AS e
SET "userId" = s."userId"
FROM "Subscription" AS s
WHERE e."subscriptionId" = s."id";

UPDATE "SubscriptionEvent"
SET "userId" = ("payload" #>> '{data,object,metadata,userId}')::uuid
WHERE "userId" IS NULL
  AND "provider" = 'STRIPE'
  AND ("payload" #>> '{data,object,metadata,userId}') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

UPDATE "SubscriptionEvent"
SET "userId" = ("payload" #>> '{event,app_user_id}')::uuid
WHERE "userId" IS NULL
  AND "provider" = 'REVENUECAT'
  AND ("payload" #>> '{event,app_user_id}') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

-- CreateIndex
CREATE INDEX "SubscriptionEvent_userId_idx" ON "SubscriptionEvent"("userId");
