import { Redis } from 'ioredis';
import { type PinoLogger } from 'nestjs-pino';
import { type RedisService } from '../src/infrastructure/cache/redis.service';
import { CoachCancellations } from '../src/modules/coach/infrastructure/coach-cancellations';

/**
 * « Arrêter » contre un VRAI Redis : la demande traverse les exemplaires de
 * l'API, et seule une demande faite PENDANT le tour l'arrête.
 */
describe('CoachCancellations (Redis réel)', () => {
  let client: Redis;
  const cancellations = () =>
    new CoachCancellations(
      { getClient: () => client } as unknown as RedisService,
      { warn: () => undefined } as unknown as PinoLogger,
    );
  const settled = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

  beforeAll(() => {
    client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
  });
  afterAll(async () => {
    await client.quit();
  });
  beforeEach(async () => {
    const keys = [
      ...(await client.keys('coach:cancel:*')),
      ...(await client.keys('coach:turn:m*')),
    ];
    if (keys.length > 0) await client.del(...keys);
    // Le tour de « m1 » s'écrit (le verrou que pose `holdTurn`).
    await client.set('coach:turn:m1', 'jeton', 'PX', 60_000);
  });

  it('demandé sur un AUTRE exemplaire pendant le tour : arrêté dans la seconde', async () => {
    const tour = cancellations().watch('u1', 'm1');
    await cancellations().request('u1', 'm1');
    await settled(1_300);
    expect(tour.signal.aborted).toBe(true);
    await tour.dispose();
    expect(await client.exists('coach:cancel:u1:m1')).toBe(0);
  });

  it('sans tour en cours, rien n’est posé : le renvoi ne s’arrêtera pas d’office', async () => {
    await client.del('coach:turn:m1');
    await cancellations().request('u1', 'm1');
    expect(await client.exists('coach:cancel:u1:m1')).toBe(0);
  });

  it('l’arrêt d’autrui, ou d’un autre message, ne touche pas ce tour', async () => {
    const api = cancellations();
    const tour = api.watch('u1', 'm1');
    await api.request('u2', 'm1');
    await api.request('u1', 'm2');
    await settled(1_300);
    expect(tour.signal.aborted).toBe(false);
    await tour.dispose();
  });
});
