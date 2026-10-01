import { CoachWorkerPool } from './coach-worker-pool';

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

  it('prend le worker le moins occupé', () => {
    const workers = pool();
    const first = workers.acquire();
    const second = workers.acquire();

    expect(new Set([first.url, second.url])).toEqual(new Set([A, B]));
    workers.release(first, false);
    expect(workers.acquire().url).toBe(first.url);
  });

  it('la suite d’un tour retourne au worker qui l’a commencé, même plus occupé', () => {
    // Lui seul a la conversation en cache : ailleurs, elle se relirait en entier.
    const workers = pool();
    const started = workers.acquire();
    const other = started.url === A ? B : A;
    expect(workers.acquire(new Set(), started.name).url).toBe(started.url);
    // En panne, il n'est plus préféré : le tour continue ailleurs.
    workers.release(started, true);
    expect(workers.acquire(new Set(), started.name).url).toBe(other);
  });

  it('écarte un worker en panne, puis le reprend après sa mise de côté', () => {
    const workers = pool();
    const down = workers.acquire();
    workers.release(down, true);

    const other = down.url === A ? B : A;
    expect(workers.acquire().url).toBe(other);
    expect(workers.acquire().url).toBe(other);

    now += 30_001;
    expect(workers.status().find((w) => w.url === down.url)?.healthy).toBe(true);
  });

  it('tous en panne : tente quand même le premier revenu, plutôt que refuser', () => {
    const workers = pool();
    const a = workers.acquire();
    workers.release(a, true);
    now += 10;
    const b = workers.acquire();
    workers.release(b, true);

    expect(workers.acquire().url).toBe(a.url);
  });

  it('une nouvelle tentative évite le worker qui vient d’échouer', () => {
    const workers = pool();
    const tried = workers.acquire();
    workers.release(tried, true);

    expect(workers.acquire(new Set([tried.url])).url).not.toBe(tried.url);
  });

  it('l’état ne livre que l’hôte, jamais le chemin ni d’éventuels identifiants', () => {
    const workers = pool(['http://user:secret@gpu.interne:11434/v1']);
    expect(workers.status()[0]?.name).toBe('gpu.interne:11434');
  });

  it('sans aucun worker configuré, acquire le dit au lieu de rendre undefined', () => {
    expect(() => pool([]).acquire()).toThrow('Aucun worker');
  });
});
