import { type PrismaClient } from '@prisma/client';
import { ERASE_ACCOUNT_TIMEOUT_MS, PrismaDeletedAccountsLedger } from './deleted-accounts-ledger';

describe('PrismaDeletedAccountsLedger.eraseAccount', () => {
  it('efface dans une transaction au délai de la purge, pas aux 5 s d’une requête HTTP', async () => {
    const tx = {
      user: {
        count: jest.fn().mockResolvedValue(1),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      subscriptionEvent: { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) },
    };
    const $transaction = jest.fn(
      (work: (client: typeof tx) => Promise<boolean>, _options?: { timeout?: number }) => work(tx),
    );
    const leagueMembership = { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) };
    const ledger = new PrismaDeletedAccountsLedger({
      $transaction,
      leagueMembership,
    } as unknown as PrismaClient);

    await expect(ledger.eraseAccount('compte')).resolves.toBe(true);

    expect($transaction.mock.calls[0]?.[1]?.timeout).toBe(ERASE_ACCOUNT_TIMEOUT_MS);
    expect(ERASE_ACCOUNT_TIMEOUT_MS).toBeGreaterThanOrEqual(60_000);
  });

  it('la ligue part AVANT la cascade, dans une écriture courte à elle', async () => {
    // Chaque ligne supprimée décrémente l'effectif de son groupe ; dans la
    // longue cascade, ce verrou aurait fait attendre tous les placements.
    const ordre: string[] = [];
    const tx = {
      user: {
        count: jest.fn().mockResolvedValue(1),
        deleteMany: jest.fn(() => (ordre.push('cascade'), Promise.resolve({ count: 1 }))),
      },
      subscriptionEvent: { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) },
    };
    const leagueMembership = {
      deleteMany: jest.fn(() => (ordre.push('ligue'), Promise.resolve({ count: 2 }))),
    };
    const ledger = new PrismaDeletedAccountsLedger({
      $transaction: (work: (client: typeof tx) => Promise<boolean>) => work(tx),
      leagueMembership,
    } as unknown as PrismaClient);

    await ledger.eraseAccount('compte');

    expect(ordre).toEqual(['ligue', 'cascade']);
    expect(leagueMembership.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'compte', user: { status: 'DELETED' } },
    });
  });
});
