import { type Prisma, type Subscription } from '@prisma/client';
import { type PinoLogger } from 'nestjs-pino';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { type AppConfigService } from '../../../config/app-config.service';
import { type StripeSubscriptionClient } from '../infrastructure/stripe-subscription.client';
import { type SubscriptionsRepository } from '../infrastructure/subscriptions.repository';
import { AccountBillingService, BILLING_NOT_STOPPED } from './account-billing.service';

function abonnement(id: string, provider: Subscription['provider']): Subscription {
  return { id, provider, externalSubscriptionId: `ext_${id}` } as Subscription;
}

function build(options: {
  billables: Subscription[];
  configured?: boolean;
  production?: boolean;
  cancelNow?: jest.Mock;
}) {
  const repo = {
    billableSubscriptions: jest.fn().mockResolvedValue(options.billables),
    markCanceled: jest.fn().mockResolvedValue(undefined),
  };
  const stripe = {
    isConfigured: options.configured ?? true,
    cancelNow: options.cancelNow ?? jest.fn().mockResolvedValue(undefined),
  };
  const logger = { warn: jest.fn(), error: jest.fn() };
  const service = new AccountBillingService(
    repo as unknown as SubscriptionsRepository,
    stripe as unknown as StripeSubscriptionClient,
    { isProduction: options.production ?? false } as unknown as AppConfigService,
    logger as unknown as PinoLogger,
  );
  return { service, repo, stripe, logger };
}

describe('AccountBillingService', () => {
  it('le plan : Stripe à résilier, magasin signalé', async () => {
    const { service } = build({
      billables: [abonnement('s1', 'STRIPE'), abonnement('r1', 'REVENUECAT')],
    });

    await expect(service.plan('u1')).resolves.toEqual({
      stripe: [{ id: 's1', externalSubscriptionId: 'ext_s1' }],
      storeSubscriptionStillActive: true,
    });
  });

  it('aucun abonnement qui prélève : rien à arrêter, rien à signaler', async () => {
    const { service, stripe } = build({ billables: [] });

    const plan = await service.plan('u1');
    expect(plan).toEqual({ stripe: [], storeSubscriptionStillActive: false });
    await expect(service.stop(plan, 'req')).resolves.toEqual([]);
    expect(stripe.cancelNow).not.toHaveBeenCalled();
  });

  it('résilie chaque abonnement Stripe, et rend ceux qui le sont', async () => {
    const { service, stripe } = build({
      billables: [abonnement('s1', 'STRIPE'), abonnement('s2', 'STRIPE')],
    });

    const arretes = await service.stop(await service.plan('u1'), 'req');

    expect(stripe.cancelNow.mock.calls).toEqual([
      ['ext_s1', 'req'],
      ['ext_s2', 'req'],
    ]);
    expect(arretes).toEqual(['s1', 's2']);
  });

  it('Stripe échoue : 503 écrit pour la personne, et le compte n’est pas supprimé', async () => {
    const { service, logger } = build({
      billables: [abonnement('s1', 'STRIPE')],
      cancelNow: jest.fn().mockRejectedValue(new Error('HTTP 500')),
    });

    const echec = service.stop(await service.plan('u1'), 'req-9');

    await expect(echec).rejects.toBeInstanceOf(UserFacingUnavailableException);
    await expect(echec).rejects.toThrow(BILLING_NOT_STOPPED);
    expect(BILLING_NOT_STOPPED).toBe(
      'On n’a pas pu arrêter ton abonnement, réessaie dans un instant ; ton compte n’est pas supprimé.',
    );
    expect(logger.error).toHaveBeenCalledWith(
      expect.objectContaining({ requestId: 'req-9', subscriptionId: 's1' }),
      expect.any(String),
    );
  });

  it('Stripe non configuré hors production : suppression permise, journalisée', async () => {
    const { service, stripe, logger } = build({
      billables: [abonnement('s1', 'STRIPE')],
      configured: false,
    });

    await expect(service.stop(await service.plan('u1'), 'req')).resolves.toEqual([]);
    expect(stripe.cancelNow).not.toHaveBeenCalled();
    expect(logger.warn).toHaveBeenCalled();
  });

  it('Stripe non configuré EN PRODUCTION : refus, personne ne reste prélevé en silence', async () => {
    const { service, stripe } = build({
      billables: [abonnement('s1', 'STRIPE')],
      configured: false,
      production: true,
    });

    await expect(service.stop(await service.plan('u1'), 'req')).rejects.toBeInstanceOf(
      UserFacingUnavailableException,
    );
    expect(stripe.cancelNow).not.toHaveBeenCalled();
  });

  it('dans la transaction, les abonnements arrêtés passent CANCELED', async () => {
    const { service, repo } = build({ billables: [] });
    const tx = { marqueur: 'transaction' } as unknown as Prisma.TransactionClient;

    await service.markStopped(['s1'], tx);
    await service.markStopped([], tx);

    expect(repo.markCanceled).toHaveBeenCalledTimes(1);
    expect(repo.markCanceled).toHaveBeenCalledWith(['s1'], tx);
  });

  describe('événement Stripe pour un compte supprimé ou effacé', () => {
    it('un abonnement qui prélève encore est résilié à réception', async () => {
      const { service, stripe } = build({ billables: [] });

      await service.stopForAbsentAccount('sub_tardif', 'active');

      expect(stripe.cancelNow).toHaveBeenCalledWith('sub_tardif', expect.any(String));
    });

    it.each(['canceled', 'incomplete_expired', undefined])(
      'statut %s : plus rien ne prélève, rien à faire',
      async (statut) => {
        const { service, stripe } = build({ billables: [] });

        await service.stopForAbsentAccount('sub_fini', statut);

        expect(stripe.cancelNow).not.toHaveBeenCalled();
      },
    );

    it('Stripe échoue : l’erreur remonte, pour que le webhook soit réémis', async () => {
      const { service } = build({
        billables: [],
        cancelNow: jest.fn().mockRejectedValue(new Error('HTTP 500')),
      });

      await expect(service.stopForAbsentAccount('sub_tardif', 'active')).rejects.toThrow(
        'HTTP 500',
      );
    });

    it('Stripe non configuré : rien de possible, journalisé', async () => {
      const { service, stripe, logger } = build({ billables: [], configured: false });

      await service.stopForAbsentAccount('sub_tardif', 'active');

      expect(stripe.cancelNow).not.toHaveBeenCalled();
      expect(logger.error).toHaveBeenCalled();
    });
  });
});
