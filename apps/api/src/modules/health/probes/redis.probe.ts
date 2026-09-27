import { type HealthComponent } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { RedisService } from '../../../infrastructure/cache/redis.service';
import { runProbe } from './run-probe';

@Injectable()
export class RedisHealthProbe {
  readonly key = 'redis';

  constructor(
    private readonly redis: RedisService,
    @InjectPinoLogger(RedisHealthProbe.name)
    private readonly logger: PinoLogger,
  ) {}

  check(): Promise<HealthComponent> {
    return runProbe('Redis', () => this.redis.ping(), this.logger);
  }
}
