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
 */
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import {
  productsFromConfig,
  syncSubscriptionCatalog,
} from '../modules/subscriptions/application/subscription-catalog-sync';

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
    process.stdout.write(
      [
        'Catalogue d’abonnement projeté.',
        `  plans            : ${summary.plans}`,
        `  droits ouverts   : ${summary.entitlements}`,
        `  produits liés    : ${summary.products}`,
        // Un catalogue SANS produit est lisible mais ne peut rien accorder :
        // le dire ici évite de découvrir le trou au premier paiement réel.
        ...(summary.products === 0
          ? [
              '',
              'ATTENTION : aucun identifiant produit configuré — aucun paiement ne',
              'pourra accorder Premium. Renseigner STRIPE_PRICE_MONTHLY /',
              'STRIPE_PRICE_YEARLY (et REVENUECAT_PRODUCT_* pour les magasins),',
              'puis relancer cette commande.',
            ]
          : []),
        '',
      ].join('\n'),
    );
    return summary.products === 0 ? 1 : 0;
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
