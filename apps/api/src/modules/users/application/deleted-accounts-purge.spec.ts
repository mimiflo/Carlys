import { InMemoryObjectStore } from '../../../../test/support/in-memory-object-store';
import { type DeletedAccountsLedger, purgeDeletedAccounts } from './deleted-accounts-purge';

/// CE QUE CE FICHIER PROTÈGE : la purge efface les comptes SUPPRIMÉS depuis
/// plus que le délai, photos privées d'abord, et rien d'autre.

const MAINTENANT = new Date('2026-09-25T12:00:00Z');

interface Supprime {
  readonly id: string;
  readonly deletedAt: Date;
}

function compte(id: string, joursDepuis: number): Supprime {
  return { id, deletedAt: new Date(MAINTENANT.getTime() - joursDepuis * 86_400_000) };
}

class FauxRegistre implements DeletedAccountsLedger {
  readonly effaces: string[] = [];
  readonly ordre: string[] = [];
  constructor(private readonly comptes: Supprime[]) {}

  listDeletedBefore(before: Date): Promise<string[]> {
    return Promise.resolve(
      this.comptes
        .filter((c) => c.deletedAt < before && !this.effaces.includes(c.id))
        .map((c) => c.id),
    );
  }

  isDeleted(id: string): Promise<boolean> {
    return Promise.resolve(this.comptes.some((c) => c.id === id));
  }

  eraseAccount(id: string): Promise<boolean> {
    this.ordre.push(`base ${id}`);
    this.effaces.push(id);
    return Promise.resolve(true);
  }
}

async function photo(store: InMemoryObjectStore, userId: string, nom: string): Promise<void> {
  await store.put(`meal-photos/${userId}/${nom}.jpg`, Buffer.from('x'), 'image/jpeg');
}

describe('purgeDeletedAccounts', () => {
  it('efface les comptes supprimés depuis plus que le délai, photos comprises, et eux seuls', async () => {
    const registre = new FauxRegistre([compte('ancien', 40), compte('recent', 5)]);
    const store = new InMemoryObjectStore();
    await photo(store, 'ancien', 'a');
    await photo(store, 'ancien', 'b');
    await photo(store, 'recent', 'c');

    const rapport = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      dryRun: false,
    });

    expect(rapport).toEqual({
      eligible: 1,
      erased: 1,
      objectsDeleted: 2,
      failures: [],
      refused: null,
    });
    expect(registre.effaces).toEqual(['ancien']);
    expect([...store.objects.keys()]).toEqual(['meal-photos/recent/c.jpg']);
  });

  it('à blanc : compte, n’efface rien', async () => {
    const registre = new FauxRegistre([compte('ancien', 40)]);
    const store = new InMemoryObjectStore();
    await photo(store, 'ancien', 'a');

    const rapport = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      dryRun: true,
    });

    expect(rapport.eligible).toBe(1);
    expect(registre.effaces).toEqual([]);
    expect(store.objects.size).toBe(1);
  });

  it('stockage en panne : la base n’est PAS effacée, le passage suivant réessaiera', async () => {
    const registre = new FauxRegistre([compte('ancien', 40)]);
    const store = new InMemoryObjectStore();
    await photo(store, 'ancien', 'a');
    store.failDeletes = true;

    const rapport = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      dryRun: false,
    });

    expect(rapport.erased).toBe(0);
    expect(rapport.failures).toHaveLength(1);
    expect(registre.effaces).toEqual([]);
  });

  it('--compte : efface tout de suite un compte supprimé, refuse un compte qui ne l’est pas', async () => {
    const registre = new FauxRegistre([compte('hier', 1)]);
    const store = new InMemoryObjectStore();

    const immediat = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      accountId: 'hier',
      dryRun: false,
    });
    expect(immediat.erased).toBe(1);

    const refus = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      accountId: 'actif',
      dryRun: false,
    });
    expect(refus.refused).toContain('n’est pas un compte supprimé');
    expect(refus.erased).toBe(0);
  });
});
