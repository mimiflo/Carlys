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
    const ledger = new PrismaDeletedAccountsLedger({ $transaction } as unknown as PrismaClient);

    await expect(ledger.eraseAccount('compte')).resolves.toBe(true);

    expect($transaction.mock.calls[0]?.[1]?.timeout).toBe(ERASE_ACCOUNT_TIMEOUT_MS);
    expect(ERASE_ACCOUNT_TIMEOUT_MS).toBeGreaterThanOrEqual(60_000);
  });
});
