import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { purgePrefix } from './purge-prefix';
import { RedisService } from './redis.service';

/**
 * Cache JSON au-dessus de Redis, tolérant aux pannes : si Redis est
 * indisponible, les lectures répondent null et les écritures sont ignorées
 * (journalisé) — la base de données reste la source de vérité.
 */
@Injectable()
export class CacheService {
  constructor(
    private readonly redis: RedisService,
    @InjectPinoLogger(CacheService.name)
    private readonly logger: PinoLogger,
  ) {}

  async getJson<T>(key: string): Promise<T | null> {
    try {
      const raw = await this.redis.getClient().get(key);
      return raw === null ? null : (JSON.parse(raw) as T);
    } catch (error) {
      this.logger.warn({ err: error, key }, 'Cache indisponible en lecture');
      return null;
    }
  }

  async setJson(key: string, value: unknown, ttlSeconds: number): Promise<void> {
    try {
      await this.redis.getClient().set(key, JSON.stringify(value), 'EX', ttlSeconds);
    } catch (error) {
      this.logger.warn({ err: error, key }, 'Cache indisponible en écriture');
    }
  }

  /**
   * Invalidation explicite par préfixe — le parcours vit dans
   * `purge-prefix.ts`, partagé avec `dist/cli/catalog-seed`.
   */
  async invalidatePrefix(prefix: string): Promise<void> {
    try {
      await purgePrefix(this.redis.getClient(), prefix);
    } catch (error) {
      this.logger.warn({ err: error, prefix }, "Cache indisponible pour l'invalidation");
    }
  }
}
