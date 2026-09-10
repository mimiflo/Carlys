import { Module } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
import { AppConfigService } from '../../config/app-config.service';
import { RedisThrottlerStorage } from './redis-throttler.storage';
import { ThrottlerStorageModule } from './throttler-storage.module';

/**
 * Limitation de débit de l'API, comptée dans Redis donc partagée par tous les
 * réplicas.
 *
 * Le module réunit le réglage (fenêtre et plafond, lus dans la configuration)
 * et le stockage partagé : `AppModule` l'importe à la place de
 * `ThrottlerModule.forRootAsync`, et rien d'autre dans le dépôt n'a à savoir
 * où le compteur est tenu.
 */
@Module({
  imports: [
    ThrottlerModule.forRootAsync({
      // AppConfigModule est global ; ThrottlerStorageModule ne l'est pas et
      // doit donc être importé ici pour que la fabrique puisse l'injecter.
      imports: [ThrottlerStorageModule],
      inject: [AppConfigService, RedisThrottlerStorage],
      useFactory: (config: AppConfigService, storage: RedisThrottlerStorage) => ({
        storage,
        throttlers: [
          {
            ttl: config.rateLimitTtlSeconds * 1_000,
            limit: config.rateLimitMaxRequests,
          },
        ],
      }),
    }),
  ],
  exports: [ThrottlerModule],
})
export class ThrottlingModule {}
