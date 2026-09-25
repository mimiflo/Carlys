import { InMemoryObjectStore } from '../../../../test/support/in-memory-object-store';
import { type MealPhotoLedger } from '../infrastructure/meal-photo-ledger';
import { DEFAULT_SWEEP_GRACE_MS, sweepOrphanMealPhotos } from './meal-photo-sweep';

const NOW = new Date('2026-09-25T12:00:00Z');
const OLD = new Date(NOW.getTime() - 2 * DEFAULT_SWEEP_GRACE_MS);
const RECENT = new Date(NOW.getTime() - 60_000);

async function seed(store: InMemoryObjectStore, key: string, lastModified: Date): Promise<void> {
  await store.put(key, Buffer.from('x'), 'image/jpeg');
  store.age(key, lastModified);
}

function ledgerCiting(live: readonly string[]) {
  return {
    liveKeysAmong: jest.fn((keys: readonly string[]) =>
      Promise.resolve(new Set(keys.filter((key) => live.includes(key)))),
    ),
    forgetKeys: jest.fn().mockResolvedValue(undefined),
  };
}

describe('sweepOrphanMealPhotos', () => {
  it('efface les orphelins anciens, épargne les vivants et les tout récents', async () => {
    const store = new InMemoryObjectStore();
    store.pageSize = 2;
    await seed(store, 'meal-photos/u1/vivante.jpg', OLD);
    await seed(store, 'meal-photos/u1/orpheline.jpg', OLD);
    await seed(store, 'meal-photos/u2/orpheline.jpg', OLD);
    await seed(store, 'meal-photos/u2/en-cours-de-depot.jpg', RECENT);
    await seed(store, 'autre-prefixe/intouchable.jpg', OLD);
    const ledger = ledgerCiting(['meal-photos/u1/vivante.jpg']);

    const report = await sweepOrphanMealPhotos(store, ledger as unknown as MealPhotoLedger, {
      now: NOW,
      graceMs: DEFAULT_SWEEP_GRACE_MS,
      dryRun: false,
    });

    expect(report).toEqual({ scanned: 4, live: 1, young: 1, orphans: 2, deleted: 2, failures: [] });
    expect([...store.objects.keys()].sort()).toEqual([
      'autre-prefixe/intouchable.jpg',
      'meal-photos/u1/vivante.jpg',
      'meal-photos/u2/en-cours-de-depot.jpg',
    ]);
    // Une ligne restée sous un repas supprimé part avec son objet.
    expect(ledger.forgetKeys.mock.calls.flat(2).sort()).toEqual([
      'meal-photos/u1/orpheline.jpg',
      'meal-photos/u2/orpheline.jpg',
    ]);
  });

  it('à blanc : compte, n’efface rien', async () => {
    const store = new InMemoryObjectStore();
    await seed(store, 'meal-photos/u1/orpheline.jpg', OLD);

    const report = await sweepOrphanMealPhotos(
      store,
      ledgerCiting([]) as unknown as MealPhotoLedger,
      { now: NOW, graceMs: DEFAULT_SWEEP_GRACE_MS, dryRun: true },
    );

    expect(report).toMatchObject({ orphans: 1, deleted: 0 });
    expect(store.objects.size).toBe(1);
  });

  it('un effacement qui échoue est RENDU dans le rapport, jamais tu', async () => {
    const store = new InMemoryObjectStore();
    await seed(store, 'meal-photos/u1/orpheline.jpg', OLD);
    store.failDeletes = true;

    const report = await sweepOrphanMealPhotos(
      store,
      ledgerCiting([]) as unknown as MealPhotoLedger,
      { now: NOW, graceMs: DEFAULT_SWEEP_GRACE_MS, dryRun: false },
    );

    expect(report.deleted).toBe(0);
    expect(report.failures).toEqual([
      'meal-photos/u1/orpheline.jpg : stockage injoignable (simulé)',
    ]);
  });
});
