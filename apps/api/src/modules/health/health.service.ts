import {
  type HealthComponent,
  type HealthReport,
  type LivenessReport,
} from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { DatabaseHealthProbe } from './probes/database.probe';
import { RedisHealthProbe } from './probes/redis.probe';

@Injectable()
export class HealthService {
  constructor(
    private readonly databaseProbe: DatabaseHealthProbe,
    private readonly redisProbe: RedisHealthProbe,
  ) {}

  liveness(): LivenessReport {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptimeSeconds: Math.round(process.uptime()),
    };
  }

  async readiness(): Promise<HealthReport> {
    const [database, redis] = await Promise.all([
      this.databaseProbe.check(),
      this.redisProbe.check(),
    ]);

    const components: Record<string, HealthComponent> = {
      [this.databaseProbe.key]: database,
      [this.redisProbe.key]: redis,
    };

    const allUp = Object.values(components).every((component) => component.status === 'up');

    return {
      status: allUp ? 'ok' : 'error',
      timestamp: new Date().toISOString(),
      uptimeSeconds: Math.round(process.uptime()),
      components,
    };
  }
}
