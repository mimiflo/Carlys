import { type HealthComponent } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { withTimeout } from '../../../common/utilities/with-timeout';
import { RedisService } from '../../../infrastructure/cache/redis.service';

const PROBE_TIMEOUT_MS = 2_000;

@Injectable()
export class RedisHealthProbe {
  readonly key = 'redis';

  constructor(private readonly redis: RedisService) {}

  async check(): Promise<HealthComponent> {
    const startedAt = Date.now();
    try {
      await withTimeout(this.redis.ping(), PROBE_TIMEOUT_MS, 'Redis');
      return { status: 'up', latencyMs: Date.now() - startedAt };
    } catch (error) {
      return {
        status: 'down',
        error: error instanceof Error ? error.message : 'Erreur inconnue',
      };
    }
  }
}
