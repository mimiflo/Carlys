import { type PinoLogger } from 'nestjs-pino';
import { type PrismaService } from '../../../database/prisma/prisma.service';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { DatabaseHealthProbe } from './database.probe';
import { RedisHealthProbe } from './redis.probe';
import { PROBE_DOWN_LABEL } from './run-probe';

/**
 * `/health` est PUBLIC : ce qu'une sonde renvoie se lit depuis Internet, et
 * la page d'accueil de l'administration l'affiche sans connexion. Les
 * messages ci-dessous sont ceux que Prisma et ioredis lèvent réellement
 * quand la dépendance refuse la connexion ; ils nomment l'hôte et le port
 * internes, et ne doivent sortir que vers le journal.
 */
const PRISMA_REFUS =
  "Invalid `prisma.$queryRaw()` invocation:\n\nCan't reach database server at `10.20.30.40:5432`";
const REDIS_REFUS = 'connect ECONNREFUSED 10.20.30.41:6379';

/** Un journal factice, et sa méthode `warn` à part pour l'inspecter. */
function loggerStub(): { logger: PinoLogger; warn: jest.Mock } {
  const warn = jest.fn();
  return { logger: { warn } as unknown as PinoLogger, warn };
}

describe('sondes de santé', () => {
  it('PostgreSQL en panne : libellé public, détail au journal', async () => {
    const { logger, warn } = loggerStub();
    const panne = new Error(PRISMA_REFUS);
    const prisma = { $queryRaw: jest.fn().mockRejectedValue(panne) } as unknown as PrismaService;

    const result = await new DatabaseHealthProbe(prisma, logger).check();

    expect(result).toEqual({ status: 'down', error: PROBE_DOWN_LABEL });
    expect(JSON.stringify(result)).not.toContain('10.20.30.40');
    expect(warn).toHaveBeenCalledWith(
      expect.objectContaining({ err: panne, component: 'PostgreSQL' }),
      expect.any(String),
    );
  });

  it('Redis en panne : libellé public, détail au journal', async () => {
    const { logger, warn } = loggerStub();
    const panne = new Error(REDIS_REFUS);
    const redis = { ping: jest.fn().mockRejectedValue(panne) } as unknown as RedisService;

    const result = await new RedisHealthProbe(redis, logger).check();

    expect(result).toEqual({ status: 'down', error: PROBE_DOWN_LABEL });
    expect(JSON.stringify(result)).not.toContain('10.20.30.41');
    expect(warn).toHaveBeenCalledWith(
      expect.objectContaining({ err: panne, component: 'Redis' }),
      expect.any(String),
    );
  });

  it('une sonde qui lève AVANT de rendre sa promesse est une panne, pas un 500', async () => {
    const { logger, warn } = loggerStub();
    const redis = {
      ping: () => {
        throw new Error(REDIS_REFUS);
      },
    } as unknown as RedisService;

    await expect(new RedisHealthProbe(redis, logger).check()).resolves.toEqual({
      status: 'down',
      error: PROBE_DOWN_LABEL,
    });
    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('dépendance joignable : up, latence mesurée, rien au journal', async () => {
    const { logger, warn } = loggerStub();
    const prisma = { $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]) };

    const result = await new DatabaseHealthProbe(
      prisma as unknown as PrismaService,
      logger,
    ).check();

    expect(result.status).toBe('up');
    expect(result.latencyMs).toBeGreaterThanOrEqual(0);
    expect(result.error).toBeUndefined();
    expect(warn).not.toHaveBeenCalled();
  });
});
