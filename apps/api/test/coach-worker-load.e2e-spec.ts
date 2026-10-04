import { Redis } from 'ioredis';
import { type PinoLogger } from 'nestjs-pino';
import { type RedisService } from '../src/infrastructure/cache/redis.service';
import { CoachWorkerLoad } from '../src/modules/coach/infrastructure/coach-worker-load';
import { CoachWorkerPool } from '../src/modules/coach/infrastructure/coach-worker-pool';

/**
 * La charge des workers contre un VRAI Redis : le script Lua ne se simule
 * pas. Deux « exemplaires » de l'API se partagent deux workers.
 */
describe('CoachWorkerLoad (Redis réel)', () => {
  const A = 'http://ollama:11434/v1';
  const B = 'http://gpu-2.interne:11434/v1';
  const logger = { warn: jest.fn() } as unknown as PinoLogger;
  let client: Redis;
  // L'heure RÉELLE : la clé de chaque worker expire avec son dernier bail.
  let now = Date.now();

  const load = () =>
    new CoachWorkerLoad({ getClient: () => client } as unknown as RedisService, logger);
  const api = (shared = load()) =>
    new CoachWorkerPool([A, B], 30_000, () => now, { load: shared, leaseMs: 60_000 });
  const clear = async () => {
    const keys = await client.keys('coach:worker:leases:*');
    if (keys.length > 0) await client.del(...keys);
  };

  beforeAll(() => {
    client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
  });
  afterAll(async () => {
    await clear();
    await client.quit();
  });
  beforeEach(async () => {
    now = Date.now();
    await clear();
  });

  it('deux exemplaires : le second tour va au worker que le premier laisse libre', async () => {
    const api1 = api();
    const api2 = api();

    const first = await api1.acquire();
    const second = await api2.acquire();

    expect(first.lease).toBeDefined();
    expect(second.url).not.toBe(first.url);
    expect((await api1.status()).map((w) => w.active)).toEqual([1, 1]);

    api1.release(first, false);
    expect((await api2.acquire()).url).toBe(first.url);
  });

  it('la suite d’un tour garde son worker, même plus chargé', async () => {
    const api1 = api();
    const started = await api1.acquire();
    expect((await api().acquire(new Set(), started.name)).url).toBe(started.url);
    expect((await api1.status()).find((w) => w.url === started.url)?.active).toBe(2);
  });

  it('un exemplaire mort en plein tour : son bail expire, le worker se libère', async () => {
    const mort = await api().acquire();
    now += 60_001;
    expect((await api().status()).every((w) => w.active === 0)).toBe(true);
    expect((await api().acquire()).url).toBe(mort.url);
  });
});
