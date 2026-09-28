import { BillingPeriod, PaymentProvider } from '@prisma/client';
import { type SubscriptionProductInput } from '../modules/subscriptions/application/subscription-catalog-sync';
import { paymentVerdict } from './subscription-catalog';

const STRIPE_MENSUEL: SubscriptionProductInput = {
  provider: PaymentProvider.STRIPE,
  externalProductId: 'price_mensuel',
  billingPeriod: BillingPeriod.MONTHLY,
};
const MAGASINS_ANNUEL: SubscriptionProductInput = {
  provider: PaymentProvider.REVENUECAT,
  externalProductId: 'carlys_premium_annuel',
  billingPeriod: BillingPeriod.YEARLY,
};
const CLE_STRIPE = { stripeSecretKey: 'sk_live_0123456789abcdef' };
const WEBHOOK_STRIPE = { stripeWebhookSecret: 'whsec_0123456789abcdef' };
const WEBHOOK_MAGASINS = { revenueCatWebhookSecret: 'rc_0123456789abcdef' };
const STRIPE_COMPLET = { ...CLE_STRIPE, ...WEBHOOK_STRIPE };

describe('subscription-catalog — verdict', () => {
  it('aucun moyen de paiement : rend 0 et dit que Premium passe par le back-office', () => {
    const verdict = paymentVerdict({}, []);

    expect(verdict.exitCode).toBe(0);
    expect(verdict.lines.join('\n')).toContain(
      'aucun paiement configuré sur ce serveur : Premium ne s’obtient que par le back-office',
    );
  });

  it('des produits sans moyen de paiement : rien ne peut encaisser, rend 0', () => {
    expect(paymentVerdict({}, [STRIPE_MENSUEL]).exitCode).toBe(0);
  });

  it.each([
    ['la clé Stripe', CLE_STRIPE],
    ['le secret de webhook Stripe', WEBHOOK_STRIPE],
  ])('%s sans prix Stripe : rend 1 et nomme les variables', (_nom, config) => {
    const verdict = paymentVerdict(config, []);

    expect(verdict.exitCode).toBe(1);
    expect(verdict.lines.join('\n')).toContain('STRIPE_PRICE_MONTHLY');
  });

  it('le secret de webhook RevenueCat sans produit : rend 1', () => {
    const verdict = paymentVerdict(WEBHOOK_MAGASINS, []);

    expect(verdict.exitCode).toBe(1);
    expect(verdict.lines.join('\n')).toContain('REVENUECAT_PRODUCT_MONTHLY');
  });

  it('Stripe actif sans prix, magasins actifs AVEC produits : rend 1, ne nomme que Stripe', () => {
    const verdict = paymentVerdict({ ...CLE_STRIPE, ...WEBHOOK_MAGASINS }, [MAGASINS_ANNUEL]);
    const texte = verdict.lines.join('\n');

    expect(verdict.exitCode).toBe(1);
    expect(texte).toContain('STRIPE_PRICE_MONTHLY');
    expect(texte).not.toContain('REVENUECAT_PRODUCT_MONTHLY');
  });

  it('Stripe actif avec prix, magasins actifs SANS produit : rend 1, ne nomme que RevenueCat', () => {
    const verdict = paymentVerdict({ ...STRIPE_COMPLET, ...WEBHOOK_MAGASINS }, [STRIPE_MENSUEL]);
    const texte = verdict.lines.join('\n');

    expect(verdict.exitCode).toBe(1);
    expect(texte).toContain('REVENUECAT_PRODUCT_MONTHLY');
    expect(texte).not.toContain('STRIPE_PRICE_MONTHLY');
  });

  it('chaque fournisseur actif a ses produits : rend 0, sans avertissement', () => {
    const verdict = paymentVerdict({ ...WEBHOOK_STRIPE, ...WEBHOOK_MAGASINS }, [
      STRIPE_MENSUEL,
      MAGASINS_ANNUEL,
    ]);

    expect(verdict).toEqual({ exitCode: 0, lines: [] });
  });

  it('Stripe seul, avec prix : les magasins inactifs ne demandent rien', () => {
    expect(paymentVerdict(STRIPE_COMPLET, [STRIPE_MENSUEL])).toEqual({ exitCode: 0, lines: [] });
  });

  it('clé et prix Stripe SANS secret de webhook : rend 1 — le webhook répondrait 503', () => {
    const verdict = paymentVerdict(CLE_STRIPE, [STRIPE_MENSUEL]);

    expect(verdict.exitCode).toBe(1);
    expect(verdict.lines.join('\n')).toContain('STRIPE_WEBHOOK_SECRET');
  });

  it('des abonnés Stripe qui prélèvent, plus aucune variable : rend 1, jamais « aucun paiement »', () => {
    const verdict = paymentVerdict({}, [], new Map([[PaymentProvider.STRIPE, 3]]));
    const texte = verdict.lines.join('\n');

    expect(verdict.exitCode).toBe(1);
    expect(texte).toContain('3 abonnement(s) Stripe prélèvent encore');
    expect(texte).toContain('STRIPE_WEBHOOK_SECRET');
    expect(texte).not.toContain('aucun paiement configuré');
  });

  it('des abonnés RevenueCat qui prélèvent, sans son secret : rend 1', () => {
    const verdict = paymentVerdict(
      STRIPE_COMPLET,
      [STRIPE_MENSUEL],
      new Map([[PaymentProvider.REVENUECAT, 1]]),
    );

    expect(verdict.exitCode).toBe(1);
    expect(verdict.lines.join('\n')).toContain('REVENUECAT_WEBHOOK_SECRET');
  });

  it('des abonnés Stripe servis par un Stripe complet : rend 0', () => {
    const verdict = paymentVerdict(
      STRIPE_COMPLET,
      [STRIPE_MENSUEL],
      new Map([[PaymentProvider.STRIPE, 3]]),
    );

    expect(verdict).toEqual({ exitCode: 0, lines: [] });
  });
});
