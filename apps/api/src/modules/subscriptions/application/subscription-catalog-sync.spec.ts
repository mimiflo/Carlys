import { BillingPeriod, PaymentProvider } from '@prisma/client';
import { productsFromConfig } from './subscription-catalog-sync';

/**
 * CE QUE CE FICHIER PROTÈGE : qu'un serveur sache quels produits ouvrent le
 * plan payant.
 *
 * Ces tables n'étaient écrites que par le seed de développement, qui ne
 * s'exécute jamais en déploiement. Un serveur neuf n'avait donc aucun plan,
 * et le premier webhook Stripe échouait sur « produit inconnu » — 503,
 * réémissions, abandon : le paiement encaissé, le compte toujours gratuit.
 */
describe('productsFromConfig', () => {
  it('traduit les tarifs configurés en produits du plan payant', () => {
    expect(
      productsFromConfig({
        stripePriceMonthly: 'price_live_mensuel',
        stripePriceYearly: 'price_live_annuel',
        revenueCatProductMonthly: 'carlys_premium_monthly',
        revenueCatProductYearly: 'carlys_premium_yearly',
      }),
    ).toEqual([
      {
        provider: PaymentProvider.STRIPE,
        externalProductId: 'price_live_mensuel',
        billingPeriod: BillingPeriod.MONTHLY,
      },
      {
        provider: PaymentProvider.STRIPE,
        externalProductId: 'price_live_annuel',
        billingPeriod: BillingPeriod.YEARLY,
      },
      {
        provider: PaymentProvider.REVENUECAT,
        externalProductId: 'carlys_premium_monthly',
        billingPeriod: BillingPeriod.MONTHLY,
      },
      {
        provider: PaymentProvider.REVENUECAT,
        externalProductId: 'carlys_premium_yearly',
        billingPeriod: BillingPeriod.YEARLY,
      },
    ]);
  });

  it('ignore un fournisseur non configuré plutôt que d’inventer un identifiant', () => {
    // Les magasins ne sont pas encore ouverts : RevenueCat n'a rien à dire.
    // Un identifiant inventé ne correspondrait à aucun paiement réel et
    // donnerait l'illusion d'un catalogue complet.
    const products = productsFromConfig({
      stripePriceMonthly: 'price_live_mensuel',
    });

    expect(products).toHaveLength(1);
    expect(products[0]?.provider).toBe(PaymentProvider.STRIPE);
  });

  it('rend une liste VIDE quand rien n’est configuré — le déploiement s’y arrête', () => {
    // C'est ce cas-là que la commande signale par un code d'échec : un
    // catalogue sans produit est lisible, mais aucun paiement ne peut
    // accorder Premium.
    expect(productsFromConfig({})).toEqual([]);
    expect(productsFromConfig({ stripePriceMonthly: '' })).toEqual([]);
  });
});
