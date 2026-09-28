/**
 * `node dist/cli/subscription-catalog`
 *
 * Projette le CATALOGUE D'ABONNEMENT dans la base : les plans (gratuit,
 * premium), les droits que chacun ouvre, et la correspondance vers les
 * produits Stripe / RevenueCat configurés sur CE serveur.
 *
 * POURQUOI ELLE EXISTE. Ces trois tables n'étaient écrites que par le seed
 * de développement, qui ne s'exécute jamais en déploiement — il crée des
 * comptes de démonstration. Un serveur neuf n'avait donc aucun plan : la
 * projection du premier webhook Stripe échouait sur « Produit Stripe
 * inconnu », échec classé rattrapable, donc rendu en 503. Stripe réémettait,
 * échouait autant de fois, puis abandonnait. Le paiement était encaissé et
 * le compte restait gratuit, sans un mot. Le chemin de l'argent ne pouvait
 * pas aboutir.
 *
 * Même forme que `catalog-seed` : elle réutilise exactement ce que le seed
 * utilise (`syncSubscriptionCatalog`), rien n'est recopié, et elle est
 * IDEMPOTENTE — rejouable à chaque déploiement.
 *
 * Les identifiants produits viennent de la CONFIGURATION (`STRIPE_PRICE_*`,
 * `REVENUECAT_PRODUCT_*`), jamais des valeurs factices du seed : ce sont
 * les vrais produits qui encaissent.
 *
 * Code de sortie : voir `paymentVerdict`.
 */
import { ConfigService } from '@nestjs/config';
import { PaymentProvider, PrismaClient } from '@prisma/client';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import {
  type SubscriptionProductInput,
  productsFromConfig,
  syncSubscriptionCatalog,
} from '../modules/subscriptions/application/subscription-catalog-sync';
import { BILLABLE_STATUSES } from '../modules/subscriptions/infrastructure/subscriptions.repository';

type PaymentConfig = Partial<
  Pick<AppConfigService, 'stripeSecretKey' | 'stripeWebhookSecret' | 'revenueCatWebhookSecret'>
>;

/**
 * Un fournisseur est CONFIGURÉ par une clé qui encaisse ou un secret de
 * webhook. Il ne peut rien accorder sans son secret de webhook (l'endpoint
 * répond 503) ni sans produit (le webhook échoue sur « produit inconnu »).
 * RevenueCat n'a pas de clé serveur.
 */
const PROVIDERS = [
  {
    provider: PaymentProvider.STRIPE,
    name: 'Stripe',
    configured: (config: PaymentConfig) =>
      Boolean(config.stripeSecretKey || config.stripeWebhookSecret),
    secret: (config: PaymentConfig) => config.stripeWebhookSecret,
    secretVariable: 'STRIPE_WEBHOOK_SECRET',
    productVariables: 'STRIPE_PRICE_MONTHLY / STRIPE_PRICE_YEARLY',
  },
  {
    provider: PaymentProvider.REVENUECAT,
    name: 'RevenueCat (magasins)',
    configured: (config: PaymentConfig) => Boolean(config.revenueCatWebhookSecret),
    secret: (config: PaymentConfig) => config.revenueCatWebhookSecret,
    secretVariable: 'REVENUECAT_WEBHOOK_SECRET',
    productVariables: 'REVENUECAT_PRODUCT_MONTHLY / REVENUECAT_PRODUCT_YEARLY',
  },
];

/**
 * Rend 1 — et le déploiement s'arrête — quand un paiement peut être encaissé
 * sans rien accorder : un fournisseur configuré, ou qui a encore des abonnés
 * qui prélèvent (`billable`, compté en base), à qui manque son secret de
 * webhook ou tout produit. Sans l'un ni l'autre, rien à protéger : 0, et
 * l'avertissement que Premium passe par le back-office.
 */
export function paymentVerdict(
  config: PaymentConfig,
  products: readonly SubscriptionProductInput[],
  billable: ReadonlyMap<PaymentProvider, number> = new Map(),
): { exitCode: 0 | 1; lines: string[] } {
  const concerned = PROVIDERS.filter(
    (entry) => entry.configured(config) || billable.has(entry.provider),
  );
  if (concerned.length === 0) {
    return {
      exitCode: 0,
      lines: [
        '',
        'AVERTISSEMENT — aucun paiement configuré sur ce serveur : Premium ne s’obtient que par le back-office.',
      ],
    };
  }
  const problems = concerned.flatMap((entry) => {
    const missing = [
      ...(entry.secret(config) ? [] : [entry.secretVariable]),
      ...(products.some((product) => product.provider === entry.provider)
        ? []
        : [entry.productVariables]),
    ];
    if (missing.length === 0) {
      return [];
    }
    const count = billable.get(entry.provider);
    const why =
      count === undefined
        ? `${entry.name} est configuré sur ce serveur`
        : `${count} abonnement(s) ${entry.name} prélèvent encore`;
    return [
      `ATTENTION : ${why}, mais sans ${missing.join(' ni ')} un paiement serait ` +
        `encaissé sans rien accorder. Renseigner ${missing.join(', ')}.`,
    ];
  });
  if (problems.length === 0) {
    return { exitCode: 0, lines: [] };
  }
  return { exitCode: 1, lines: ['', ...problems, 'Puis relancer cette commande.'] };
}

async function main(): Promise<number> {
  let config: AppConfigService;
  try {
    const env: Env = validateEnv(process.env);
    config = new AppConfigService(new ConfigService<Env, true>(env));
  } catch (error) {
    process.stderr.write(`Échec : ${(error as Error).message}\n`);
    return 1;
  }

  const products = productsFromConfig(config);
  const prisma = new PrismaClient({ datasourceUrl: config.databaseUrl });
  try {
    const summary = await syncSubscriptionCatalog(prisma, products);
    const billable = await prisma.subscription.groupBy({
      by: ['provider'],
      where: { status: { in: [...BILLABLE_STATUSES] } },
      _count: { _all: true },
    });
    const verdict = paymentVerdict(
      config,
      products,
      new Map(billable.map((row) => [row.provider, row._count._all])),
    );
    process.stdout.write(
      [
        'Catalogue d’abonnement projeté.',
        `  plans            : ${summary.plans}`,
        `  droits ouverts   : ${summary.entitlements}`,
        `  produits liés    : ${summary.products}`,
        ...verdict.lines,
        '',
      ].join('\n'),
    );
    return verdict.exitCode;
  } catch (error) {
    process.stderr.write(`Échec : ${(error as Error).message}\n`);
    return 1;
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error: unknown) => {
      process.stderr.write(`Échec : ${(error as Error).message}\n`);
      process.exitCode = 1;
    });
}
