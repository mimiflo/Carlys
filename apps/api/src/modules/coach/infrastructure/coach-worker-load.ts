import { Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { RedisService } from '../../../infrastructure/cache/redis.service';

/**
 * Les baux d'un worker : un ensemble trié, score = fin du bail. La clé porte
 * une EMPREINTE de l'adresse, jamais l'adresse : celle-ci peut contenir des
 * identifiants (`https://nom:secret@hôte/v1`), que `SCAN`, `MONITOR` et les
 * sauvegardes de Redis montreraient en clair.
 */
const leasesOf = (url: string) =>
  `coach:worker:leases:${createHash('sha256').update(url).digest('hex').slice(0, 16)}`;

/**
 * Choix atomique parmi KEYS (dans l'ordre) : ARGV[4] > 0 impose ce rang (la
 * suite d'un tour), sinon le moins chargé, le premier à égalité. Pose le bail
 * ARGV[3] jusqu'à ARGV[2] ; rend le rang choisi (1…n).
 */
const CLAIM = `
for _, key in ipairs(KEYS) do redis.call('ZREMRANGEBYSCORE', key, '-inf', ARGV[1]) end
local best = tonumber(ARGV[4])
if best == 0 then
  local least
  for i, key in ipairs(KEYS) do
    local load = redis.call('ZCARD', key)
    if least == nil or load < least then best, least = i, load end
  end
end
redis.call('ZADD', KEYS[best], ARGV[2], ARGV[3])
-- La clé vit jusqu'au bail le PLUS LONG qu'elle porte, pas jusqu'au dernier
-- posé : un autre exemplaire peut tenir un bail plus long (réglage, horloge).
local last = redis.call('ZRANGE', KEYS[best], -1, -1, 'WITHSCORES')
redis.call('PEXPIREAT', KEYS[best], last[2])
return best
`;

/**
 * Les générations en cours sur chaque worker, PARTAGÉES par tous les
 * exemplaires de l'API (ADR 0013) : sans elles, chaque exemplaire ne voit que
 * les siennes, et deux API envoient leurs tours au même worker « libre ».
 *
 * Un bail par génération, qui expire seul : un exemplaire mort en plein tour
 * ne laisse pas un worker occupé pour toujours. Redis indisponible : `null`,
 * et le pool décide sur ses compteurs locaux, comme avant. Jamais d'exception.
 */
@Injectable()
export class CoachWorkerLoad {
  constructor(
    private readonly redis: RedisService,
    @InjectPinoLogger(CoachWorkerLoad.name) private readonly logger: PinoLogger,
  ) {}

  /** Rang (0…n-1) du worker choisi parmi `urls`, bail posé ; `null` sans Redis. */
  async claim(
    urls: readonly string[],
    prefer: number,
    lease: string,
    until: number,
    now: number,
  ): Promise<number | null> {
    try {
      const keys = urls.map(leasesOf);
      const rank = await this.redis
        .getClient()
        .eval(CLAIM, keys.length, ...keys, now, until, lease, prefer + 1);
      return Number(rank) - 1;
    } catch (error) {
      this.logger.warn({ err: error }, 'Charge partagée des workers illisible : choix local');
      return null;
    }
  }

  async release(url: string, lease: string): Promise<void> {
    await this.redis
      .getClient()
      .zrem(leasesOf(url), lease)
      .catch((error: unknown) =>
        // Le bail expirera seul : rien n'est bloqué pour autant.
        this.logger.warn({ err: error }, 'Bail de worker non rendu'),
      );
  }

  /** Générations en cours par worker, tous exemplaires confondus ; `null` sans Redis. */
  async counts(urls: readonly string[], now: number): Promise<number[] | null> {
    try {
      const client = this.redis.getClient();
      return await Promise.all(urls.map((url) => client.zcount(leasesOf(url), `(${now}`, '+inf')));
    } catch (error) {
      this.logger.warn({ err: error }, 'Charge partagée des workers illisible');
      return null;
    }
  }
}
