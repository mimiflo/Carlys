import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
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
    const limit = this.config.coachGateway.dailyMessageLimit;
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

  /**
   * Verrou d'UNE question pendant qu'on y répond : rend de quoi le lever, ou
   * `null` s'il est déjà tenu. Il expire seul après la plus longue durée
   * d'un tour, file et génération en flux comprises (plus une marge) : une API tuée en plein tour ne bloque pas la question.
   * La levée ne supprime que SON verrou, jamais celui d'un tour suivant.
   */
  async holdTurn(messageId: string): Promise<(() => Promise<void>) | null> {
    const client = this.redis.getClient();
    const key = `coach:turn:${messageId}`;
    const token = randomUUID();
    // Attente dans la file PUIS génération : le plus long qu'un tour puisse tenir.
    const { queueTimeoutMs, requestTimeoutMs } = this.config.coachGateway;
    const held = await client.set(
      key,
      token,
      'PX',
      queueTimeoutMs + requestTimeoutMs + 20_000,
      'NX',
    );
    if (held === null) {
      return null;
    }
    return async () => {
      if ((await client.get(key)) === token) {
        await client.del(key);
      }
    };
  }

  /**
   * Rythme : `COACH_MESSAGES_PER_MINUTE` par personne, sur l'identité
   * Carlys — jamais l'adresse IP. Freine un script sans toucher au quota du
   * jour : un refus ici ne consomme rien.
   */
  async withinRate(userId: string, now: Date = new Date()): Promise<boolean> {
    const minute = Math.floor(now.getTime() / 60_000);
    const key = `coach:rate:${userId}:${minute}`;
    const client = this.redis.getClient();
    const sent = await client.incr(key);
    if (sent === 1) {
      await client.expire(key, 120);
    }
    return sent <= this.config.coachGateway.messagesPerMinute;
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
    const limit = this.config.coachGateway.dailyMessageLimit;
    const raw = await this.redis.getClient().get(CoachQuota.keyFor(userId, now));
    const used = raw === null ? 0 : Number.parseInt(raw, 10);
    return Math.max(0, limit - (Number.isFinite(used) ? used : 0));
  }
}
