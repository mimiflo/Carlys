import { Global, Module } from '@nestjs/common';
import { CacheService } from './cache.service';
import { RedisService } from './redis.service';
import { SessionCache } from './session-cache';

@Global()
@Module({
  providers: [RedisService, CacheService, SessionCache],
  exports: [RedisService, CacheService, SessionCache],
})
export class RedisModule {}
