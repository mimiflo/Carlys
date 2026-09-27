import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { LockoutService } from './lockout.service';

interface FakeRedisClient {
  incr: jest.Mock;
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
    ttl: jest.fn(() => Promise.resolve(300)),
    expire: jest.fn(() => Promise.resolve(1)),
    del: jest.fn((key: string) => {
      counters.delete(key);
      return Promise.resolve(1);
    }),
  };
}

function buildService(
  client: FakeRedisClient,
  logger: { warn: jest.Mock } = { warn: jest.fn() },
): LockoutService {
  const redis = { getClient: () => client } as unknown as RedisService;
  const config = {
    maxLoginAttempts: 3,
    lockoutMinutes: 15,
    logFingerprintKey: Buffer.from('cle-de-test'),
  } as unknown as AppConfigService;
  return new LockoutService(redis, config, logger as unknown as PinoLogger);
}

describe('LockoutService', () => {
  it('reset : fail-open journalisé quand Redis est indisponible', async () => {
    const logger = { warn: jest.fn() };
    const broken = { ...fakeClient(), del: jest.fn(() => Promise.reject(new Error('down'))) };
    const service = buildService(broken, logger);

    await expect(service.reset('a@b.fr')).resolves.toBeUndefined();
    expect(logger.warn).toHaveBeenCalledTimes(1);
  });

  describe('reserveAttempt', () => {
    it('parmi des essais SIMULTANÉS, exactement le seuil est permis', async () => {
      const client = fakeClient();
      const service = buildService(client);

      const verdicts = await Promise.all(
        Array.from({ length: 10 }, () => service.reserveAttempt('a@b.fr')),
      );

      expect(verdicts.filter((verdict) => !verdict.locked)).toHaveLength(3);
      expect(verdicts.filter((verdict) => verdict.locked)).toHaveLength(7);
      expect(verdicts.find((verdict) => verdict.locked)?.retryAfterSeconds).toBe(300);
    });

    it('la fenêtre repart à chaque essai permis, jamais pendant le verrouillage', async () => {
      const client = fakeClient();
      const service = buildService(client);

      for (let i = 0; i < 6; i += 1) {
        await service.reserveAttempt('a@b.fr');
      }

      expect(client.expire).toHaveBeenCalledTimes(3);
      expect(client.expire).toHaveBeenLastCalledWith('auth:lockout:a@b.fr', 900);
    });

    it('un succès (reset) rouvre les essais', async () => {
      const service = buildService(fakeClient());
      for (let i = 0; i < 3; i += 1) {
        await service.reserveAttempt('a@b.fr');
      }
      expect((await service.reserveAttempt('a@b.fr')).locked).toBe(true);

      await service.reset('a@b.fr');

      expect(await service.reserveAttempt('a@b.fr')).toEqual({ locked: false });
    });

    it('une clé restée sans échéance est bornée, sinon le compte resterait fermé pour toujours', async () => {
      const client = fakeClient();
      client.ttl.mockResolvedValue(-1);
      const service = buildService(client);
      for (let i = 0; i < 3; i += 1) {
        await service.reserveAttempt('a@b.fr');
      }
      client.expire.mockClear();

      expect(await service.reserveAttempt('a@b.fr')).toEqual({
        locked: true,
        retryAfterSeconds: 900,
      });
      expect(client.expire).toHaveBeenCalledWith('auth:lockout:a@b.fr', 900);
    });

    it('fail-open quand Redis est indisponible', async () => {
      const broken = { ...fakeClient(), incr: jest.fn(() => Promise.reject(new Error('down'))) };
      const service = buildService(broken);

      expect(await service.reserveAttempt('a@b.fr')).toEqual({ locked: false });
    });
  });

  it('le verrouillage se journalise sous une EMPREINTE, jamais l’adresse visée', async () => {
    const logger = { warn: jest.fn() };
    const service = buildService(fakeClient(), logger);

    // Seuil à 3 : trois refus de suite, UNE seule ligne, au premier.
    for (let i = 0; i < 6; i += 1) {
      await service.reserveAttempt('admin:victime@carlys.test');
    }

    expect(logger.warn).toHaveBeenCalledTimes(1);
    expect(JSON.stringify(logger.warn.mock.calls)).not.toContain('victime@carlys.test');
    expect((logger.warn.mock.calls as unknown[][])[0]?.[0]).toEqual({
      identifierHash: expect.stringMatching(/^[0-9a-f]{12}$/) as unknown,
    });
  });
});
