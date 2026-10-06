import { randomUUID } from 'node:crypto';
import { Injectable, type OnModuleInit } from '@nestjs/common';
import { type Redis } from 'ioredis';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { RedisService } from './redis.service';

/**
 * Au plus 30 s de vie pour une entrée : le filet si une invalidation échoue
 * (Redis qui lit mais refuse d'écrire). Au-delà, la base reprend la main.
 */
export const SESSION_CACHE_TTL_SECONDS = 30;

/** Champ du hachage qui porte la GÉNÉRATION : changée à chaque fermeture. */
const GENERATION = '_gen';

/**
 * Plafond d'une commande : un Redis figé (sauvegarde, connexion à demi
 * morte) garde son statut `ready`, et chaque requête authentifiée
 * l'attendrait. Au-delà, la base.
 */
const COMMAND_TIMEOUT_MS = 250;

/** Un avertissement par fenêtre, pas un par requête quand Redis flanche. */
const WARN_INTERVAL_MS = 30_000;

const LOOKUP_COMMAND = 'carlysSessionLookup';
const REMEMBER_COMMAND = 'carlysSessionRemember';

const keyOf = (userId: string): string => `auth:sessions:${userId}`;

/**
 * Le TTL ne se pose qu'une fois — un hachage sans cesse rafraîchi vivrait
 * plus de 30 s — et sans `EXPIRE … NX`, réservé à Redis 7.
 */
const EXPIRE_ONCE = `if redis.call('TTL', KEYS[1]) == -1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end`;

/**
 * La lecture du garde, qui ASSURE une génération : un hachage absent (jamais
 * créé, évincé, Redis redémarré) en reçoit une neuve. Une génération vide
 * ne se compare donc jamais : sans cela, une clé perdue entre une
 * révocation et la remise en cache laissait repasser la session fermée.
 */
const LOOKUP = `
redis.call('HSETNX', KEYS[1], '${GENERATION}', ARGV[2])
${EXPIRE_ONCE}
return redis.call('HMGET', KEYS[1], ARGV[3], '${GENERATION}')`;

/**
 * N'écrit que si la génération n'a pas bougé depuis la lecture du garde.
 * Sans ce contrôle, un garde qui a lu la base JUSTE AVANT une révocation
 * remettrait en cache, juste après elle, la session qu'elle vient de fermer.
 */
const REMEMBER_IF_UNCHANGED = `
local gen = redis.call('HGET', KEYS[1], '${GENERATION}')
if not gen or gen ~= ARGV[2] then return 0 end
redis.call('HSET', KEYS[1], ARGV[3], ARGV[4])
${EXPIRE_ONCE}
return 1`;

/**
 * Les deux scripts, greffés par `defineCommand` (EVALSHA, repli sur EVAL) :
 * leur corps ne traverse le réseau qu'une fois. Même motif, et même seule
 * conversion de type, que `RedisThrottlerStorage`.
 */
interface RedisWithSessionCommands extends Redis {
  [LOOKUP_COMMAND]: (
    key: string,
    ttlSeconds: string,
    freshGeneration: string,
    sessionId: string,
  ) => Promise<[string | null, string | null]>;
  [REMEMBER_COMMAND]: (
    key: string,
    ttlSeconds: string,
    generation: string,
    sessionId: string,
    expiresAtMs: string,
  ) => Promise<number>;
}

/** La commande, ou un rejet passé [COMMAND_TIMEOUT_MS]. */
function borne<T>(command: Promise<T>): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const delai = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error('Redis trop lent')), COMMAND_TIMEOUT_MS);
  });
  return Promise.race([command, delai]).finally(() => clearTimeout(timer));
}

export interface CachedSession {
  /** Échéance en millisecondes, ou `null` : absente du cache. */
  readonly expiresAt: number | null;
  /** Génération lue, jamais vide — à rendre telle quelle à [SessionCache.remember]. */
  readonly generation: string;
}

/**
 * Les sessions VALIDES, en cache Redis : le garde JWT relisait la session en
 * base à CHAQUE requête authentifiée — la requête la plus fréquente de
 * l'API, et autant de connexions du pool PostgreSQL prises pour rien.
 *
 * Un hachage par compte (`auth:sessions:<userId>`, champ = session,
 * valeur = échéance) : toute fermeture invalide le compte entier en une
 * écriture, celle d'une session comme celle de toutes. Jamais d'entrée
 * négative : une session inconnue, révoquée ou expirée va à la base.
 *
 * Redis indisponible : la base, comme avant — jamais un refus, jamais un
 * laissez-passer.
 */
@Injectable()
export class SessionCache implements OnModuleInit {
  private lastWarnAt = 0;

  constructor(
    private readonly redis: RedisService,
    @InjectPinoLogger(SessionCache.name)
    private readonly logger: PinoLogger,
  ) {}

  onModuleInit(): void {
    const client = this.redis.getClient();
    client.defineCommand(LOOKUP_COMMAND, { numberOfKeys: 1, lua: LOOKUP });
    client.defineCommand(REMEMBER_COMMAND, { numberOfKeys: 1, lua: REMEMBER_IF_UNCHANGED });
  }

  private get client(): RedisWithSessionCommands {
    return this.redis.getClient() as RedisWithSessionCommands;
  }

  /** `null` : cache indisponible — lire la base, et ne rien y écrire. */
  async lookup(userId: string, sessionId: string): Promise<CachedSession | null> {
    const client = this.client;
    // Pas de file d'attente : un Redis en reconnexion ferait attendre CHAQUE
    // requête authentifiée.
    if (client.status !== 'ready') {
      return null;
    }
    try {
      const [expiresAt, generation] = await borne(
        client[LOOKUP_COMMAND](
          keyOf(userId),
          String(SESSION_CACHE_TTL_SECONDS),
          randomUUID(),
          sessionId,
        ),
      );
      if (generation === null) {
        return null;
      }
      return { expiresAt: expiresAt === null ? null : Number(expiresAt), generation };
    } catch (error) {
      this.warnOnce(error);
      return null;
    }
  }

  /** Après une lecture en base qui a trouvé la session valide. */
  async remember(
    userId: string,
    sessionId: string,
    expiresAt: Date,
    generation: string,
  ): Promise<void> {
    try {
      await borne(
        this.client[REMEMBER_COMMAND](
          keyOf(userId),
          String(SESSION_CACHE_TTL_SECONDS),
          generation,
          sessionId,
          String(expiresAt.getTime()),
        ),
      );
    } catch (error) {
      this.warnOnce(error);
    }
  }

  /**
   * APRÈS LE COMMIT de toute écriture qui ferme une session de `userId`
   * (révocation, suppression) : avant, un garde pourrait relire la base
   * encore ouverte et remettre l'entrée. Ne lève jamais — la fermeture a eu
   * lieu ; l'entrée périmée meurt au plus tard dans 30 s.
   */
  async forget(userId: string): Promise<void> {
    const key = keyOf(userId);
    try {
      await borne(
        this.client
          .multi()
          .del(key)
          .hset(key, GENERATION, randomUUID())
          .expire(key, SESSION_CACHE_TTL_SECONDS)
          .exec(),
      );
    } catch (error) {
      this.logger.error(
        { err: error, userId },
        'Cache des sessions non invalidé : la session fermée peut servir encore 30 s',
      );
    }
  }

  private warnOnce(error: unknown): void {
    const now = Date.now();
    if (now - this.lastWarnAt < WARN_INTERVAL_MS) {
      return;
    }
    this.lastWarnAt = now;
    this.logger.warn({ err: error }, 'Cache des sessions indisponible : la base répond');
  }
}
