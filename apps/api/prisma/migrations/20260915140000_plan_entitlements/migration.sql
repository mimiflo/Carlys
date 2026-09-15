-- La correspondance plan → droits passe du CODE à la DONNÉE.
--
-- Ce qu'elle remplace. `EntitlementsService.syncFromSubscription` reconnaissait
-- le plan à son slug (`plan.slug === 'premium'`) puis réécrivait, à chaque
-- événement d'abonnement, la liste `PREMIUM_ENTITLEMENT_KEYS` codée dans
-- `packages/api-contracts`. L'ADR 0006 l'interdit en toutes lettres — « aucun
-- test de nom de plan en dur ; toute condition d'accès nomme un droit » — et
-- pour une raison qui coûte de l'argent : le jour où un second plan payant
-- existe, son événement ne « vaut » pas premium, donc la boucle écrit
-- `isActive: false` sur TOUS les droits premium du compte. Un membre déjà
-- Premium qui achète le second plan est rétrogradé par son propre achat, et un
-- acheteur du seul second plan paie pour un compte gratuit. Aucune erreur,
-- l'événement est marqué traité : la panne est silencieuse.
--
-- Après cette migration, chaque plan PORTE ses droits, et la synchronisation
-- ne réécrit que les clés couvertes par les plans du compte.
CREATE TABLE "SubscriptionPlanEntitlement" (
    "planId" UUID NOT NULL,
    "entitlementKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SubscriptionPlanEntitlement_pkey" PRIMARY KEY ("planId", "entitlementKey")
);

ALTER TABLE "SubscriptionPlanEntitlement"
    ADD CONSTRAINT "SubscriptionPlanEntitlement_planId_fkey"
    FOREIGN KEY ("planId") REFERENCES "SubscriptionPlan"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- REPRISE DE L'EXISTANT, et elle n'est pas facultative : sans elle, le premier
-- webhook après déploiement trouverait un plan `premium` sans aucun droit
-- déclaré, et couperait l'accès de tous les abonnés. Les six clés recopiées
-- ici sont exactement celles que `PREMIUM_ENTITLEMENT_KEYS` portait au moment
-- de cette migration — c'est un CLICHÉ de l'état d'alors, pas une source de
-- vérité : à partir d'ici, c'est cette table qui fait foi, et le seed la
-- maintient.
INSERT INTO "SubscriptionPlanEntitlement" ("planId", "entitlementKey")
SELECT p."id", k."key"
FROM "SubscriptionPlan" p
CROSS JOIN (
    VALUES
        ('unlimited_programs'),
        ('advanced_statistics'),
        ('premium_exercises'),
        ('cloud_backup'),
        ('priority_support'),
        ('ai_coaching')
) AS k("key")
WHERE p."slug" = 'premium'
ON CONFLICT DO NOTHING;
