import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
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

  /** Invalidation explicite par préfixe (SCAN, jamais KEYS). */
  async invalidatePrefix(prefix: string): Promise<void> {
    try {
      const client = this.redis.getClient();
      let cursor = '0';
      do {
        const [nextCursor, keys] = await client.scan(cursor, 'MATCH', `${prefix}*`, 'COUNT', 100);
        cursor = nextCursor;
        if (keys.length > 0) {
          await client.del(...keys);
        }
      } while (cursor !== '0');
    } catch (error) {
      this.logger.warn({ err: error, prefix }, "Cache indisponible pour l'invalidation");
    }
  }
}
