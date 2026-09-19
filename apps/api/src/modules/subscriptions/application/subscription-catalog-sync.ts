import { type EntitlementKey, PREMIUM_ENTITLEMENT_KEYS } from '@carlys/api-contracts';
import { BillingPeriod, PaymentProvider, type PrismaClient } from '@prisma/client';

/**
 * LE CATALOGUE D'ABONNEMENT : les plans, les droits qu'ils ouvrent, et la
 * correspondance vers les produits de chaque fournisseur.
 *
 * POURQUOI CE FICHIER EXISTE. Ces trois tables n'étaient écrites que par
 * le seed de DÉVELOPPEMENT — qui ne s'exécute jamais sur un serveur, parce
 * qu'il crée des comptes de démonstration. Un serveur fraîchement déployé
 * n'avait donc AUCUN plan, et la projection d'un webhook Stripe échouait
 * sur « Produit Stripe inconnu ». Cet échec est classé rattrapable, donc
 * rendu en 503 : Stripe réémettait, échouait autant de fois, puis
 * abandonnait. Le paiement était encaissé et le compte restait gratuit,
 * définitivement — le chemin de l'argent ne pouvait pas aboutir.
 *
 * Même remède que le RBAC admin (`syncAdminRbac`) : une fonction
 * idempotente appelée par le seed ET par une commande de déploiement.
 *
 * Les identifiants produits viennent d'ARGUMENT, pas d'une constante : en
 * développement ils sont factices, sur un serveur ce sont les vrais
 * `price_…` de Stripe et les identifiants des magasins. C'est précisément
 * ce que le seed ne pouvait pas faire.
 */

export interface SubscriptionProductInput {
  readonly provider: PaymentProvider;
  readonly externalProductId: string;
  readonly billingPeriod: BillingPeriod;
}

export interface SubscriptionCatalogSummary {
  readonly plans: number;
  readonly entitlements: number;
  readonly products: number;
}

const PLANS: readonly {
  slug: string;
  name: string;
  entitlements: readonly EntitlementKey[];
}[] = [
  { slug: 'free', name: 'Gratuit', entitlements: [] },
  { slug: 'premium', name: 'Premium', entitlements: PREMIUM_ENTITLEMENT_KEYS },
];

/** Le plan que les produits payants ouvrent. */
const PAID_PLAN_SLUG = 'premium';

/**
 * Projette plans, droits et produits. IDEMPOTENT : rejouable à volonté.
 *
 * Les produits passés REMPLACENT ceux du plan payant pour les fournisseurs
 * cités : un identifiant retiré de la configuration disparaît de la base,
 * sinon un ancien `price_…` continuerait d'ouvrir des droits. Les
 * fournisseurs absents de la liste ne sont pas touchés — configurer Stripe
 * seul n'efface pas ce que RevenueCat a posé.
 */
export async function syncSubscriptionCatalog(
  prisma: PrismaClient,
  products: readonly SubscriptionProductInput[],
): Promise<SubscriptionCatalogSummary> {
  for (const plan of PLANS) {
    await prisma.subscriptionPlan.upsert({
      where: { slug: plan.slug },
      update: { name: plan.name },
      create: { slug: plan.slug, name: plan.name },
    });
  }

  // Les droits EN DONNÉE (ADR 0006) : le calcul ne reconnaît plus un plan à
  // son slug. Sans ces lignes, un plan existe mais n'ouvre rien, et le
  // premier webhook coupe l'accès de ses abonnés.
  let entitlements = 0;
  for (const plan of PLANS) {
    const row = await prisma.subscriptionPlan.findUniqueOrThrow({
      where: { slug: plan.slug },
    });
    for (const key of plan.entitlements) {
      await prisma.subscriptionPlanEntitlement.upsert({
        where: { planId_entitlementKey: { planId: row.id, entitlementKey: key } },
        update: {},
        create: { planId: row.id, entitlementKey: key },
      });
      entitlements += 1;
    }
    // Un droit RETIRÉ du code doit disparaître de la base : sinon la
    // synchronisation n'est plus idempotente, seulement additive.
    await prisma.subscriptionPlanEntitlement.deleteMany({
      where: { planId: row.id, entitlementKey: { notIn: [...plan.entitlements] } },
    });
  }

  const paid = await prisma.subscriptionPlan.findUniqueOrThrow({
    where: { slug: PAID_PLAN_SLUG },
  });
  for (const product of products) {
    await prisma.subscriptionProduct.upsert({
      where: {
        provider_externalProductId: {
          provider: product.provider,
          externalProductId: product.externalProductId,
        },
      },
      update: { planId: paid.id, billingPeriod: product.billingPeriod },
      create: {
        planId: paid.id,
        provider: product.provider,
        externalProductId: product.externalProductId,
        billingPeriod: product.billingPeriod,
      },
    });
  }

  const touchedProviders = [...new Set(products.map((product) => product.provider))];
  if (touchedProviders.length > 0) {
    await prisma.subscriptionProduct.deleteMany({
      where: {
        planId: paid.id,
        provider: { in: touchedProviders },
        externalProductId: { notIn: products.map((product) => product.externalProductId) },
      },
    });
  }

  return { plans: PLANS.length, entitlements, products: products.length };
}

/**
 * Les produits décrits par la configuration d'un serveur.
 *
 * Un fournisseur non configuré n'entre pas dans la liste : mieux vaut un
 * catalogue partiel et dit qu'un identifiant inventé qui ne correspondra à
 * aucun paiement réel.
 */
export function productsFromConfig(config: {
  readonly stripePriceMonthly?: string;
  readonly stripePriceYearly?: string;
  readonly revenueCatProductMonthly?: string;
  readonly revenueCatProductYearly?: string;
}): SubscriptionProductInput[] {
  const products: SubscriptionProductInput[] = [];
  const add = (
    provider: PaymentProvider,
    externalProductId: string | undefined,
    billingPeriod: BillingPeriod,
  ): void => {
    if (externalProductId !== undefined && externalProductId.length > 0) {
      products.push({ provider, externalProductId, billingPeriod });
    }
  };
  add(PaymentProvider.STRIPE, config.stripePriceMonthly, BillingPeriod.MONTHLY);
  add(PaymentProvider.STRIPE, config.stripePriceYearly, BillingPeriod.YEARLY);
  add(PaymentProvider.REVENUECAT, config.revenueCatProductMonthly, BillingPeriod.MONTHLY);
  add(PaymentProvider.REVENUECAT, config.revenueCatProductYearly, BillingPeriod.YEARLY);
  return products;
}
