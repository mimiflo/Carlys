-- Client Stripe de l'abonnement : appris par webhook, réutilisé au prochain
-- paiement, requis par le portail de gestion (Billing Portal).
-- Migration écrite à la main, alignée sur les conventions Prisma.

-- AlterTable
ALTER TABLE "Subscription" ADD COLUMN "externalCustomerId" TEXT;
