import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { LockoutService } from './lockout.service';

interface FakeRedisClient {
  incr: jest.Mock;
  get: jest.Mock;
  ttl: jest.Mock;
  expire: jest.Mock;
  del: jest.Mock;
}

function fakeClient(): FakeRedisClient {
  const counters = new Map<string, number>();
  return {
    incr: jest.fn((key: string) => {
      const next = (counters.get(key) ?? 0) + 1;
      counters.set(key, next);
      return Promise.resolve(next);
    }),
    get: jest.fn((key: string) => Promise.resolve(counters.get(key)?.toString() ?? null)),
    ttl: jest.fn(() => Promise.resolve(300)),
    expire: jest.fn(() => Promise.resolve(1)),
    del: jest.fn((key: string) => {
      counters.delete(key);
      return Promise.resolve(1);
    }),
  };
}

function buildService(client: FakeRedisClient): LockoutService {
  const redis = { getClient: () => client } as unknown as RedisService;
  const config = { maxLoginAttempts: 3, lockoutMinutes: 15 } as unknown as AppConfigService;
  const logger = { warn: jest.fn() } as unknown as PinoLogger;
  return new LockoutService(redis, config, logger);
}

describe('LockoutService', () => {
  it('ne verrouille pas sous le seuil', async () => {
    const client = fakeClient();
    const service = buildService(client);

    await service.recordFailure('a@b.fr');
    await service.recordFailure('a@b.fr');

    expect(await service.status('a@b.fr')).toEqual({ locked: false });
  });

  it('verrouille au seuil avec le délai restant', async () => {
    const client = fakeClient();
    const service = buildService(client);

    await service.recordFailure('a@b.fr');
    await service.recordFailure('a@b.fr');
    await service.recordFailure('a@b.fr');

    const status = await service.status('a@b.fr');
    expect(status.locked).toBe(true);
    expect(status.retryAfterSeconds).toBe(300);
    // La fenêtre est reposée à chaque échec.
    expect(client.expire).toHaveBeenCalledTimes(3);
    expect(client.expire).toHaveBeenLastCalledWith('auth:lockout:a@b.fr', 900);
  });

  it('reset efface le compteur', async () => {
    const client = fakeClient();
    const service = buildService(client);

    await service.recordFailure('a@b.fr');
    await service.recordFailure('a@b.fr');
    await service.recordFailure('a@b.fr');
    await service.reset('a@b.fr');

    expect(await service.status('a@b.fr')).toEqual({ locked: false });
  });

  it('fail-open journalisé quand Redis est indisponible', async () => {
    const broken = {
      incr: jest.fn(() => Promise.reject(new Error('down'))),
      get: jest.fn(() => Promise.reject(new Error('down'))),
      ttl: jest.fn(),
      expire: jest.fn(),
      del: jest.fn(() => Promise.reject(new Error('down'))),
    };
    const service = buildService(broken);

    await expect(service.recordFailure('a@b.fr')).resolves.toBeUndefined();
    await expect(service.reset('a@b.fr')).resolves.toBeUndefined();
    expect(await service.status('a@b.fr')).toEqual({ locked: false });
  });
});
