import { PaymentProvider, SubscriptionStatus } from '@prisma/client';
import { type PrismaService } from '../../../database/prisma/prisma.service';
import { SubscriptionsRepository, type UpsertSubscriptionInput } from './subscriptions.repository';

/**
 * CE QUE CE FICHIER PROTÈGE : un webhook plus ANCIEN ne rembobine pas
 * l'abonnement d'un membre à jour.
 *
 * Les webhooks n'arrivent pas dans l'ordre d'émission — un réessai après une
 * coupure réseau, ou le parallélisme du fournisseur, suffit à livrer un
 * événement ancien après un plus récent. L'écriture était inconditionnelle :
 * un `customer.subscription.updated` émis AVANT un renouvellement mais livré
 * APRÈS réécrivait la période à jour avec l'ancienne, et l'accès se coupait
 * jusqu'au prochain événement — c'est-à-dire un mois.
 *
 * La comparaison est de la logique PURE, testée ici sans base : `$transaction`
 * est simulé et rend la main à la fonction, exactement comme Prisma. Le
 * parcours complet contre PostgreSQL vit dans `subscriptions.e2e-spec.ts` et
 * ne tourne qu'avec l'infrastructure.
 */

const MAINTENANT = new Date('2026-09-15T12:00:00.000Z');
const PLUS_TOT = new Date('2026-09-15T10:00:00.000Z');
const PLUS_TARD = new Date('2026-09-15T14:00:00.000Z');

/**
 * Les écritures sont typées sur leur ARGUMENT, pas laissées en `jest.Mock`
 * nu : `mock.calls` serait alors un `any[]`, et les assertions sur ce qui a
 * été écrit ne vérifieraient plus rien que le compilateur puisse tenir.
 */
type Ecriture = jest.Mock<Promise<unknown>, [{ data: Record<string, unknown> }]>;

interface Tx {
  findUnique: jest.Mock;
  create: Ecriture;
  update: Ecriture;
}

function buildTx(existing: unknown): Tx {
  return {
    findUnique: jest.fn().mockResolvedValue(existing),
    create: jest.fn(({ data }) => Promise.resolve(data)) as Ecriture,
    update: jest.fn(({ data }) => Promise.resolve(data)) as Ecriture,
  };
}

function repositoryOn(tx: Tx): SubscriptionsRepository {
  const prisma = {
    $transaction: (fn: (client: { subscription: Tx }) => Promise<unknown>) =>
      fn({ subscription: tx }),
  };
  return new SubscriptionsRepository(prisma as unknown as PrismaService);
}

function input(overrides: Partial<UpsertSubscriptionInput> = {}): UpsertSubscriptionInput {
  return {
    userId: 'user-1',
    planId: 'plan-premium',
    provider: PaymentProvider.STRIPE,
    externalSubscriptionId: 'sub_ext_1',
    status: SubscriptionStatus.ACTIVE,
    currentPeriodStart: null,
    currentPeriodEnd: null,
    cancelAtPeriodEnd: false,
    trialEndsAt: null,
    externalCustomerId: null,
    eventAt: MAINTENANT,
    ...overrides,
  };
}

describe('SubscriptionsRepository.upsertSubscription — ordre des événements', () => {
  it('aucun abonnement encore : création, la date d’émission est retenue', async () => {
    const tx = buildTx(null);

    const { stale } = await repositoryOn(tx).upsertSubscription(input());

    expect(stale).toBe(false);
    expect(tx.create.mock.calls[0]?.[0].data).toMatchObject({ lastEventAt: MAINTENANT });
  });

  it('événement plus RÉCENT : appliqué, et le repère avance', async () => {
    const tx = buildTx({ id: 'sub-1', lastEventAt: PLUS_TOT, plan: { slug: 'premium' } });

    const { stale } = await repositoryOn(tx).upsertSubscription(input({ eventAt: PLUS_TARD }));

    expect(stale).toBe(false);
    expect(tx.update.mock.calls[0]?.[0].data).toMatchObject({ lastEventAt: PLUS_TARD });
  });

  it('événement plus ANCIEN : REFUSÉ, la ligne n’est pas touchée', async () => {
    // Le défaut, en une ligne : sans cette garde, `update` était appelé et la
    // période à jour laissait place à la périmée.
    const existant = { id: 'sub-1', lastEventAt: PLUS_TARD, plan: { slug: 'premium' } };
    const tx = buildTx(existant);

    const { subscription, stale } = await repositoryOn(tx).upsertSubscription(
      input({ eventAt: PLUS_TOT, status: SubscriptionStatus.EXPIRED }),
    );

    expect(stale).toBe(true);
    expect(tx.update).not.toHaveBeenCalled();
    // L'état COURANT est rendu : l'appelant recalcule les droits depuis lui.
    expect(subscription).toBe(existant);
  });

  it('à égalité de date : appliqué', async () => {
    // Les fournisseurs datent à la seconde et émettent plusieurs événements
    // dans la même. Refuser l'égalité ferait perdre des mises à jour
    // légitimes, pour ne rien protéger de plus.
    const tx = buildTx({ id: 'sub-1', lastEventAt: MAINTENANT, plan: { slug: 'premium' } });

    const { stale } = await repositoryOn(tx).upsertSubscription(input({ eventAt: MAINTENANT }));

    expect(stale).toBe(false);
    expect(tx.update).toHaveBeenCalled();
  });

  it('aucune date reçue : appliqué, et le repère existant est PRÉSERVÉ', async () => {
    // Deux décisions en une. Refuser faute de date fermerait la porte à un
    // fournisseur qui ne date pas ses événements ; écrire `null` effacerait
    // le repère laissé par un événement daté, et désarmerait la garde pour
    // tous les suivants.
    const tx = buildTx({ id: 'sub-1', lastEventAt: PLUS_TARD, plan: { slug: 'premium' } });

    const { stale } = await repositoryOn(tx).upsertSubscription(input({ eventAt: null }));

    expect(stale).toBe(false);
    expect(tx.update.mock.calls[0]?.[0].data).not.toHaveProperty('lastEventAt');
  });

  it('ligne sans repère (existant d’avant la migration) : appliqué', async () => {
    // `lastEventAt` est NULL sur toutes les lignes créées avant la garde :
    // aucune date d'émission n'est connue pour ce qui a déjà été appliqué.
    // Les refuser bloquerait tout abonnement en cours.
    const tx = buildTx({ id: 'sub-1', lastEventAt: null, plan: { slug: 'premium' } });

    const { stale } = await repositoryOn(tx).upsertSubscription(input({ eventAt: PLUS_TOT }));

    expect(stale).toBe(false);
    expect(tx.update).toHaveBeenCalled();
  });

  it('un client déjà connu n’est jamais effacé par un événement sans client', async () => {
    // Règle antérieure, gardée ici parce que la réécriture de la méthode
    // aurait pu la perdre : le portail de gestion en dépend.
    const tx = buildTx({ id: 'sub-1', lastEventAt: null, plan: { slug: 'premium' } });

    await repositoryOn(tx).upsertSubscription(input({ externalCustomerId: null }));

    expect(tx.update.mock.calls[0]?.[0].data).not.toHaveProperty('externalCustomerId');
  });
});
