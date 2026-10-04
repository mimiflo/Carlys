import { CoachWorkerPool, type SharedWorkerLoad } from './coach-worker-pool';

/**
 * Plusieurs Ollama derrière une seule adresse logique : le moins occupé sert,
 * celui qui tombe est mis de côté le temps de sa remise en route.
 */
describe('CoachWorkerPool', () => {
  const A = 'http://ollama:11434/v1';
  const B = 'http://gpu-2.interne:11434/v1';
  let now = 0;
  const pool = (urls = [A, B]) => new CoachWorkerPool(urls, 30_000, () => now);

  beforeEach(() => {
    now = 1_000_000;
  });

  it('prend le worker le moins occupé', async () => {
    const workers = pool();
    const first = await workers.acquire();
    const second = await workers.acquire();

    expect(new Set([first.url, second.url])).toEqual(new Set([A, B]));
    workers.release(first, false);
    expect((await workers.acquire()).url).toBe(first.url);
  });

  it('la suite d’un tour retourne au worker qui l’a commencé, même plus occupé', async () => {
    // Lui seul a la conversation en cache : ailleurs, elle se relirait en entier.
    const workers = pool();
    const started = await workers.acquire();
    const other = started.url === A ? B : A;
    expect((await workers.acquire(new Set(), started.name)).url).toBe(started.url);
    // En panne, il n'est plus préféré : le tour continue ailleurs.
    workers.release(started, true);
    expect((await workers.acquire(new Set(), started.name)).url).toBe(other);
  });

  it('écarte un worker en panne, puis le reprend après sa mise de côté', async () => {
    const workers = pool();
    const down = await workers.acquire();
    workers.release(down, true);

    const other = down.url === A ? B : A;
    expect((await workers.acquire()).url).toBe(other);
    expect((await workers.acquire()).url).toBe(other);

    now += 30_001;
    expect((await workers.status()).find((w) => w.url === down.url)?.healthy).toBe(true);
  });

  it('tous en panne : tente quand même le premier revenu, plutôt que refuser', async () => {
    const workers = pool();
    const a = await workers.acquire();
    workers.release(a, true);
    now += 10;
    const b = await workers.acquire();
    workers.release(b, true);

    expect((await workers.acquire()).url).toBe(a.url);
  });

  it('une nouvelle tentative évite le worker qui vient d’échouer', async () => {
    const workers = pool();
    const tried = await workers.acquire();
    workers.release(tried, true);

    expect((await workers.acquire(new Set([tried.url]))).url).not.toBe(tried.url);
  });

  it('l’état ne livre que l’hôte, jamais le chemin ni d’éventuels identifiants', async () => {
    const workers = pool(['http://user:secret@gpu.interne:11434/v1']);
    expect((await workers.status())[0]?.name).toBe('gpu.interne:11434');
  });

  it('sans aucun worker configuré, acquire le dit au lieu de rendre undefined', async () => {
    await expect(pool([]).acquire()).rejects.toThrow('Aucun worker');
  });

  describe('charge partagée entre exemplaires de l’API', () => {
    /** Les baux de tous les exemplaires, comme Redis les tient (sans expiration). */
    const board = () => {
      const leases = new Map<string, Set<string>>();
      const of = (url: string) => leases.get(url) ?? leases.set(url, new Set()).get(url)!;
      const load: SharedWorkerLoad['load'] = {
        claim: (urls, prefer, lease) => {
          const rank =
            prefer >= 0
              ? prefer
              : urls.reduce((best, url, i) => (of(url).size < of(urls[best]!).size ? i : best), 0);
          of(urls[rank]!).add(lease);
          return Promise.resolve(rank);
        },
        release: (url, lease) => Promise.resolve(void of(url).delete(lease)),
        counts: (urls) => Promise.resolve(urls.map((url) => of(url).size)),
      };
      return load;
    };
    const shared = (load: SharedWorkerLoad['load'], urls = [A, B]) =>
      new CoachWorkerPool(urls, 30_000, () => now, { load, leaseMs: 60_000 });

    it('deux exemplaires ne visent pas le même worker libre', async () => {
      const load = board();
      const premier = shared(load);
      const second = shared(load);

      const a = await premier.acquire();
      const b = await second.acquire();

      expect(b.url).not.toBe(a.url);
      // L'état de santé compte les générations de TOUS les exemplaires.
      expect((await second.status()).map((w) => w.active)).toEqual([1, 1]);
      premier.release(a, false);
      expect((await second.status()).find((w) => w.url === a.url)?.active).toBe(0);
    });

    it('Redis muet : le choix se fait sur les compteurs de l’exemplaire, sans bail', async () => {
      const load = { ...board(), claim: () => Promise.resolve(null) };
      const workers = shared(load);

      const first = await workers.acquire();
      const second = await workers.acquire();

      expect(first.lease).toBeUndefined();
      expect(new Set([first.url, second.url])).toEqual(new Set([A, B]));
    });
  });
});
