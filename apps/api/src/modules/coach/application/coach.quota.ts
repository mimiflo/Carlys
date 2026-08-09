import { Injectable } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { RedisService } from '../../../infrastructure/cache/redis.service';

/**
 * Plafond de messages par utilisateur et par jour.
 *
 * Le coût du coach est réel : sans plafond, une boucle côté client peut vider
 * un budget en une nuit. Le compteur s'incrémente **avant** l'appel au modèle
 * — un échec du fournisseur ne doit pas offrir un tour gratuit à qui insiste.
 */
@Injectable()
export class CoachQuota {
  constructor(
    private readonly redis: RedisService,
    private readonly config: AppConfigService,
  ) {}

  /** Jour civil UTC : les dates de Carlys sont en UTC de bout en bout. */
  static keyFor(userId: string, now: Date): string {
    return `coach:quota:${userId}:${now.toISOString().slice(0, 10)}`;
  }

  /** Secondes de vie de la clé : deux jours, largement de quoi couvrir la date. */
  private static readonly ttlSeconds = 172_800;

  /**
   * Consomme un message. Renvoie ce qu'il reste APRÈS consommation, ou `null`
   * si le plafond est déjà atteint — l'appelant répond alors `RATE_LIMITED`.
   */
  async consume(userId: string, now: Date = new Date()): Promise<number | null> {
    const limit = this.config.coachDailyMessageLimit;
    const key = CoachQuota.keyFor(userId, now);
    const client = this.redis.getClient();

    const used = await client.incr(key);
    if (used === 1) {
      await client.expire(key, CoachQuota.ttlSeconds);
    }

    if (used > limit) {
      return null;
    }
    return limit - used;
  }

  /** Lecture seule, pour informer l'écran sans rien consommer. */
  async remaining(userId: string, now: Date = new Date()): Promise<number> {
    const limit = this.config.coachDailyMessageLimit;
    const raw = await this.redis.getClient().get(CoachQuota.keyFor(userId, now));
    const used = raw === null ? 0 : Number.parseInt(raw, 10);
    return Math.max(0, limit - (Number.isFinite(used) ? used : 0));
  }
}
