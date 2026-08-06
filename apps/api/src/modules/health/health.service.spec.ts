import { type HealthComponent } from '@carlys/api-contracts';
import { HealthService } from './health.service';
import { type DatabaseHealthProbe } from './probes/database.probe';
import { type RedisHealthProbe } from './probes/redis.probe';

function probeStub(key: string, result: HealthComponent): DatabaseHealthProbe & RedisHealthProbe {
  return {
    key,
    check: jest.fn().mockResolvedValue(result),
  } as unknown as DatabaseHealthProbe & RedisHealthProbe;
}

describe('HealthService', () => {
  it('liveness répond toujours ok avec un uptime', () => {
    const service = new HealthService(
      probeStub('database', { status: 'up' }),
      probeStub('redis', { status: 'up' }),
    );

    const report = service.liveness();

    expect(report.status).toBe('ok');
    expect(report.uptimeSeconds).toBeGreaterThanOrEqual(0);
    expect(new Date(report.timestamp).getTime()).not.toBeNaN();
  });

  it('readiness est ok quand toutes les sondes sont up', async () => {
    const service = new HealthService(
      probeStub('database', { status: 'up', latencyMs: 3 }),
      probeStub('redis', { status: 'up', latencyMs: 1 }),
    );

    const report = await service.readiness();

    expect(report.status).toBe('ok');
    expect(report.components['database']?.status).toBe('up');
    expect(report.components['redis']?.status).toBe('up');
  });

  it('readiness est en erreur dès qu"une sonde est down', async () => {
    const service = new HealthService(
      probeStub('database', { status: 'down', error: 'connexion refusée' }),
      probeStub('redis', { status: 'up' }),
    );

    const report = await service.readiness();

    expect(report.status).toBe('error');
    expect(report.components['database']?.status).toBe('down');
    expect(report.components['database']?.error).toBe('connexion refusée');
  });
});
