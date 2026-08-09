import { type Redis } from 'ioredis';
import { type AppConfigService } from '../../../config/app-config.service';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { CoachQuota } from './coach.quota';

/**
 * Plafond quotidien du coach.
 *
 * Le coût est réel : ce compteur est la seule chose entre une boucle côté
 * client et une facture. Il s'incrémente AVANT l'appel au modèle — un échec du
 * fournisseur ne doit pas offrir un tour gratuit à qui insiste.
 */
describe('CoachQuota', () => {
  const USER = 'user-1';

  function fakeRedis(): { redis: RedisService; store: Map<string, number>; expiries: string[] } {
    const store = new Map<string, number>();
    const expiries: string[] = [];
    const client = {
      incr: (key: string) => {
        const next = (store.get(key) ?? 0) + 1;
        store.set(key, next);
        return Promise.resolve(next);
      },
      expire: (key: string) => {
        expiries.push(key);
        return Promise.resolve(1);
      },
      get: (key: string) => Promise.resolve(store.get(key)?.toString() ?? null),
    } as unknown as Redis;
    return { redis: { getClient: () => client } as RedisService, store, expiries };
  }

  const config = (limit: number) => ({ coachDailyMessageLimit: limit }) as AppConfigService;

  it('décompte les messages et renvoie ce qu’il reste', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(3));

    await expect(quota.consume(USER)).resolves.toBe(2);
    await expect(quota.consume(USER)).resolves.toBe(1);
    await expect(quota.consume(USER)).resolves.toBe(0);
  });

  it('renvoie null une fois le plafond atteint', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(1));

    await expect(quota.consume(USER)).resolves.toBe(0);
    await expect(quota.consume(USER)).resolves.toBeNull();
    // Et il reste refusé : le compteur ne se relâche pas au tour suivant.
    await expect(quota.consume(USER)).resolves.toBeNull();
  });

  it('pose l’expiration une seule fois, à la première consommation', async () => {
    const { redis, expiries } = fakeRedis();
    const quota = new CoachQuota(redis, config(5));

    await quota.consume(USER);
    await quota.consume(USER);

    expect(expiries).toHaveLength(1);
  });

  it('sépare les utilisateurs et les jours', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(1));
    const lundi = new Date('2026-08-10T22:00:00.000Z');
    const mardi = new Date('2026-08-11T06:00:00.000Z');

    await expect(quota.consume(USER, lundi)).resolves.toBe(0);
    await expect(quota.consume(USER, lundi)).resolves.toBeNull();
    // Jour suivant : le compteur repart.
    await expect(quota.consume(USER, mardi)).resolves.toBe(0);
    // Autre utilisateur : compteur distinct.
    await expect(quota.consume('user-2', lundi)).resolves.toBe(0);
  });

  it('la clé est en UTC — les dates de Carlys le sont de bout en bout', () => {
    // 23 h à Paris en été, c'est encore le 10 en UTC : le plafond ne doit pas
    // se réinitialiser au milieu de la soirée d'un utilisateur.
    expect(CoachQuota.keyFor(USER, new Date('2026-08-10T21:00:00.000Z'))).toBe(
      `coach:quota:${USER}:2026-08-10`,
    );
  });

  it('lit ce qu’il reste sans rien consommer', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(4));

    await quota.consume(USER);
    await expect(quota.remaining(USER)).resolves.toBe(3);
    await expect(quota.remaining(USER)).resolves.toBe(3);
  });

  it('ne descend jamais sous zéro', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(1));

    await quota.consume(USER);
    await quota.consume(USER);

    await expect(quota.remaining(USER)).resolves.toBe(0);
  });
});
