import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';
import { DatabaseHealthProbe } from './probes/database.probe';
import { RedisHealthProbe } from './probes/redis.probe';

@Module({
  controllers: [HealthController],
  providers: [HealthService, DatabaseHealthProbe, RedisHealthProbe],
})
export class HealthModule {}
