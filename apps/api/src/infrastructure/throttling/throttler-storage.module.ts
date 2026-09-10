import { Module } from '@nestjs/common';
import { RedisThrottlerStorage } from './redis-throttler.storage';

/**
 * Le seul rôle de ce module est de rendre le compteur injectable dans la
 * fabrique de `ThrottlerModule.forRootAsync` : `ThrottlerAsyncOptions` n'offre
 * pas d'`extraProviders`, seulement `imports` et `inject`. Il faut donc un
 * module à importer, si mince soit-il.
 */
@Module({
  providers: [RedisThrottlerStorage],
  exports: [RedisThrottlerStorage],
})
export class ThrottlerStorageModule {}
