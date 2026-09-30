import { Injectable } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { RedisService } from '../../../infrastructure/cache/redis.service';

/**
 * La file et les créneaux de génération du coach, PARTAGÉS par tous les
 * exemplaires de l'API (ADR 0013).
 *
 * Trois ensembles triés dans Redis, tenus par des scripts Lua atomiques :
 * - `active` : générations en cours, score = fin du bail. Un exemplaire qui
 *   meurt en plein tour ne renouvelle plus : son créneau se libère seul ;
 * - `queue` : attentes, score = arrivée. Premier arrivé, premier servi ;
 * - `seen` : dernière présence de chaque attente. Muette depuis `STALE_MS`,
 *   elle est abandonnée (écran fermé, exemplaire tombé) et retirée.
 * Plus, par personne, ses tours en cours (file comprise), bail compris.
 */
const KEY = {
  active: 'coach:gate:active',
  queue: 'coach:gate:queue',
  seen: 'coach:gate:seen',
  user: (userId: string) => `coach:gate:user:${userId}`,
};
/** Bail d'une génération, renouvelé par la passerelle bien avant son terme. */
export const GATE_LEASE_MS = 60_000;
/** Une attente qui ne s'est pas manifestée depuis ce délai est abandonnée. */
const STALE_MS = 30_000;

/** Purge commune : baux échus, attentes abandonnées. KEYS[1..3] = active, queue, seen. */
const PURGE = `
redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', ARGV[2])
local stale = redis.call('ZRANGEBYSCORE', KEYS[3], '-inf', tonumber(ARGV[2]) - ${STALE_MS})
for _, id in ipairs(stale) do
  redis.call('ZREM', KEYS[2], id)
  redis.call('ZREM', KEYS[3], id)
end
`;

/** Entrée : place par personne, puis place dans la file (créneaux + attentes). */
const ENTER = `${PURGE}
redis.call('ZREMRANGEBYSCORE', KEYS[4], '-inf', ARGV[2])
-- Un tour de la personne qui n'est plus NI en cours NI en file (exemplaire
-- mort en plein tour, sans \`leave\`) ne la bloque pas six minutes.
for _, id in ipairs(redis.call('ZRANGE', KEYS[4], 0, -1)) do
  if not redis.call('ZSCORE', KEYS[1], id) and not redis.call('ZSCORE', KEYS[2], id) then
    redis.call('ZREM', KEYS[4], id)
  end
end
if redis.call('ZCARD', KEYS[4]) >= tonumber(ARGV[4]) then return 'user_busy' end
local load = redis.call('ZCARD', KEYS[1]) + redis.call('ZCARD', KEYS[2])
if load >= tonumber(ARGV[3]) then return 'busy' end
redis.call('ZADD', KEYS[4], tonumber(ARGV[2]) + tonumber(ARGV[5]), ARGV[1])
redis.call('PEXPIRE', KEYS[4], ARGV[5])
redis.call('ZADD', KEYS[2], ARGV[2], ARGV[1])
redis.call('ZADD', KEYS[3], ARGV[2], ARGV[1])
return 'ok'
`;

/**
 * Tour de garde d'une attente : -1 si elle obtient un créneau (dans l'ordre
 * d'arrivée), -2 si elle n'existe plus, sinon le nombre d'attentes devant elle.
 */
const POLL = `${PURGE}
local rank = redis.call('ZRANK', KEYS[2], ARGV[1])
if not rank then return -2 end
local free = tonumber(ARGV[3]) - redis.call('ZCARD', KEYS[1])
if rank < free then
  redis.call('ZREM', KEYS[2], ARGV[1])
  redis.call('ZREM', KEYS[3], ARGV[1])
  redis.call('ZADD', KEYS[1], tonumber(ARGV[2]) + tonumber(ARGV[4]), ARGV[1])
  return -1
end
redis.call('ZADD', KEYS[3], ARGV[2], ARGV[1])
return rank
`;

/** Travail de fond (résumé) : un créneau SEULEMENT si personne n'attend. */
const BACKGROUND = `${PURGE}
if redis.call('ZCARD', KEYS[2]) > 0 then return 0 end
if redis.call('ZCARD', KEYS[1]) >= tonumber(ARGV[3]) then return 0 end
redis.call('ZADD', KEYS[1], tonumber(ARGV[2]) + tonumber(ARGV[4]), ARGV[1])
return 1
`;

export type GateEntry = 'ok' | 'busy' | 'user_busy';
export type GatePoll = { acquired: true } | { acquired: false; ahead: number } | { lost: true };

@Injectable()
export class CoachGate {
  constructor(
    private readonly redis: RedisService,
    private readonly config: AppConfigService,
  ) {}

  /** Prend une place dans la file, ou dit pourquoi c'est impossible. */
  async enter(requestId: string, userId: string, now = Date.now()): Promise<GateEntry> {
    const { maxConcurrent, queueMaxSize, maxConcurrentPerUser, queueTimeoutMs, requestTimeoutMs } =
      this.config.coachGateway;
    const result = await this.eval(
      ENTER,
      [KEY.user(userId)],
      [
        requestId,
        now,
        maxConcurrent + queueMaxSize,
        maxConcurrentPerUser,
        queueTimeoutMs + requestTimeoutMs + GATE_LEASE_MS,
      ],
    );
    return result as GateEntry;
  }

  /** Obtient un créneau dans l'ordre d'arrivée, ou dit combien attendent devant. */
  async poll(requestId: string, now = Date.now()): Promise<GatePoll> {
    const result = Number(
      await this.eval(
        POLL,
        [],
        [requestId, now, this.config.coachGateway.maxConcurrent, GATE_LEASE_MS],
      ),
    );
    if (result === -1) return { acquired: true };
    if (result === -2) return { lost: true };
    return { acquired: false, ahead: result };
  }

  /** Créneau immédiat pour un travail de fond ; jamais devant une personne. */
  async tryBackground(requestId: string, now = Date.now()): Promise<boolean> {
    const result = await this.eval(
      BACKGROUND,
      [],
      [requestId, now, this.config.coachGateway.maxConcurrent, GATE_LEASE_MS],
    );
    return Number(result) === 1;
  }

  /** Prolonge le bail d'une génération en cours ; `false` si le bail était déjà perdu. */
  async renew(requestId: string, now = Date.now()): Promise<boolean> {
    const changed = await this.redis
      .getClient()
      .zadd(KEY.active, 'XX', 'CH', now + GATE_LEASE_MS, requestId);
    return Number(changed) === 1;
  }

  /** Quitte la file ou libère le créneau — les deux sans risque, idempotent. */
  async leave(requestId: string, userId?: string): Promise<void> {
    const pipeline = this.redis
      .getClient()
      .multi()
      .zrem(KEY.active, requestId)
      .zrem(KEY.queue, requestId)
      .zrem(KEY.seen, requestId);
    if (userId !== undefined) pipeline.zrem(KEY.user(userId), requestId);
    await pipeline.exec();
  }

  /** Photographie globale, pour l'état de santé. */
  async snapshot(now = Date.now()): Promise<{ active: number; queued: number }> {
    const [active, queued] = await Promise.all([
      this.redis.getClient().zcount(KEY.active, now, '+inf'),
      this.redis.getClient().zcard(KEY.queue),
    ]);
    return { active, queued };
  }

  private eval(script: string, extraKeys: string[], args: (string | number)[]): Promise<unknown> {
    const keys = [KEY.active, KEY.queue, KEY.seen, ...extraKeys];
    return this.redis.getClient().eval(script, keys.length, ...keys, ...args);
  }
}
