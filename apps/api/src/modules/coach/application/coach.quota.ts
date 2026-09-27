import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { RedisService } from '../../../infrastructure/cache/redis.service';
import { CoachProviderUnavailableException } from '../domain/coach-model.port';

/**
 * Restitutions sur panne par personne et par jour. Au-delà, une panne garde
 * le décompte : sans borne, qui insiste pendant une panne (ou la provoque en
 * saturant les limites partagées du fournisseur) l'appellerait sans fin.
 */
export const COACH_REFUNDS_PER_DAY = 3;

/**
 * Plafond quotidien atteint. `HttpException` plutôt qu'une erreur maison : le
 * filtre global la traduit en 429 / RATE_LIMITED sans code d'adaptation.
 */
export class CoachQuotaExceededError extends HttpException {
  constructor() {
    super('Tu as atteint ta limite de messages pour aujourd’hui.', HttpStatus.TOO_MANY_REQUESTS);
  }
}

/**
 * Plafond de messages par utilisateur et par jour.
 *
 * Le coût du coach est réel : sans plafond, une boucle côté client peut vider
 * un budget en une nuit. Le compteur s'incrémente **avant** l'appel au modèle,
 * atomiquement : deux envois simultanés ne passent jamais tous deux sous le
 * plafond. Un fournisseur tombé (503) avant d'avoir rien consommé REND le
 * message (`refundIfUnavailable`) : la personne n'a rien reçu, elle ne doit
 * pas le payer (décision du propriétaire, septembre 2026).
 */
@Injectable()
export class CoachQuota {
  constructor(
    private readonly redis: RedisService,
    private readonly config: AppConfigService,
  ) {}

  /** Jour civil UTC : les dates de Carlys sont en UTC de bout en bout. */
  static keyFor(userId: string, now: Date, counter: 'quota' | 'refund' = 'quota'): string {
    return `coach:${counter}:${userId}:${now.toISOString().slice(0, 10)}`;
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
    const used = await this.increment(key);

    if (used > limit) {
      // Le refus rend son incrément : sinon, sous des envois simultanés, il
      // resterait compté et avalerait un message qu'une panne aurait rendu.
      await this.redis.getClient().decr(key);
      return null;
    }
    return limit - used;
  }

  /**
   * Rend le message consommé à `now` (le MÊME instant que `consume` : passé
   * minuit, on rendrait sur le mauvais jour, et une clé sans expiration
   * naîtrait à -1) si le fournisseur est tombé SANS avoir rien consommé, et
   * `COACH_REFUNDS_PER_DAY` fois par jour au plus. Un tour qui a déjà coûté
   * des jetons, ou une panne de notre code, garde le décompte : ni l'un ni
   * l'autre ne se rejoue gratuitement. L'erreur repart toujours telle quelle.
   */
  async refundIfUnavailable(userId: string, now: Date, error: unknown): Promise<never> {
    if (
      error instanceof CoachProviderUnavailableException &&
      error.usage.inputTokens === 0 &&
      (await this.increment(CoachQuota.keyFor(userId, now, 'refund'))) <= COACH_REFUNDS_PER_DAY
    ) {
      await this.redis.getClient().decr(CoachQuota.keyFor(userId, now));
    }
    throw error;
  }

  /** INCR, et l'expiration posée à la naissance de la clé. */
  private async increment(key: string): Promise<number> {
    const client = this.redis.getClient();
    const value = await client.incr(key);
    if (value === 1) {
      await client.expire(key, CoachQuota.ttlSeconds);
    }
    return value;
  }

  /** Lecture seule, pour informer l'écran sans rien consommer. */
  async remaining(userId: string, now: Date = new Date()): Promise<number> {
    const limit = this.config.coachDailyMessageLimit;
    const raw = await this.redis.getClient().get(CoachQuota.keyFor(userId, now));
    const used = raw === null ? 0 : Number.parseInt(raw, 10);
    return Math.max(0, limit - (Number.isFinite(used) ? used : 0));
  }
}
