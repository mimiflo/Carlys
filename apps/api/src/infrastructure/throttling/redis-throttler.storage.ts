import { Injectable, type OnModuleInit } from '@nestjs/common';
import { type ThrottlerStorage, ThrottlerStorageService } from '@nestjs/throttler';
import { type Redis } from 'ioredis';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { RedisService } from '../cache/redis.service';
import { THROTTLE_LUA } from './throttle.lua';

/** Nom de la commande ajoutée au client ioredis par `defineCommand`. */
const COMMAND = 'carlysThrottle';
/** Une alerte au plus toutes les 30 s : un Redis absent ne doit pas noyer le journal. */
const WARN_INTERVAL_MS = 30_000;

/** Le tuple rendu par le script Lua : coups, ms, bloqué, ms de blocage. */
type ThrottleResult = [number, number, number, number];

/**
 * Le verdict attendu par @nestjs/throttler.
 *
 * Redéclaré ici plutôt qu'importé : `ThrottlerStorageRecord` n'est pas
 * réexporté par l'index du paquet, et aller le chercher dans son `dist/`
 * amarrerait le dépôt à l'agencement interne d'une dépendance. Le typage
 * structurel fait le reste — `implements ThrottlerStorage` ci-dessous vérifie
 * que cette forme est bien celle attendue, et cesserait de compiler si elle
 * changeait.
 */
interface VerdictDeDebit {
  totalHits: number;
  timeToExpire: number;
  isBlocked: boolean;
  timeToBlockExpire: number;
}

/**
 * `defineCommand` greffe une méthode sur le client. ioredis n'a aucun moyen de
 * la typer — elle n'existe qu'à l'exécution —, d'où cette interface qui
 * décrit exactement ce que le script attend et rend. C'est la seule
 * conversion de type du fichier, et elle porte sur une méthode que la ligne
 * `defineCommand` ci-dessous vient de créer.
 */
interface RedisWithThrottle extends Redis {
  [COMMAND]: (
    hitsKey: string,
    blockKey: string,
    ttlMs: string,
    limit: string,
    blockMs: string,
  ) => Promise<ThrottleResult>;
}

/**
 * Compteur de débit adossé à Redis, donc COMMUN à tous les réplicas de l'API.
 *
 * POURQUOI IL FALLAIT REMPLACER LE STOCKAGE PAR DÉFAUT. Celui de
 * @nestjs/throttler est une `Map` dans le processus. Avec un seul réplica il
 * est juste ; avec N réplicas, chacun compte le tiers du trafic qui lui est
 * distribué et la limite réelle devient N fois la limite annoncée. Ce n'est
 * pas un détail de justesse : la limitation de débit est ce qui protège
 * /auth/login du bourrage d'identifiants, et la faire fondre au moment précis
 * où l'on ajoute des réplicas pour absorber une charge inhabituelle revient à
 * desserrer la garde quand elle sert le plus.
 *
 * DÉGRADATION : si Redis est injoignable, on RETOMBE sur le compteur en
 * mémoire plutôt que de laisser passer. C'est moins strict qu'un compteur
 * partagé (chaque réplica compte pour lui), mais infiniment mieux que le seul
 * autre choix disponible dans un `catch` : ne rien compter du tout. La
 * readiness signale déjà Redis absent ; l'exploitation le voit là.
 *
 * FENÊTRE FIXE, PAS GLISSANTE. Le compteur en mémoire décrémente chaque coup
 * à son échéance propre ; ici la clé entière expire d'un bloc. La différence
 * se voit à cheval sur deux fenêtres, où la version en mémoire est un peu plus
 * permissive. C'est le compromis habituel de la fenêtre fixe : une commande
 * atomique au lieu d'un minuteur par requête.
 */
@Injectable()
export class RedisThrottlerStorage implements ThrottlerStorage, OnModuleInit {
  private readonly fallback = new ThrottlerStorageService();
  private lastWarnAt = 0;

  constructor(
    private readonly redis: RedisService,
    @InjectPinoLogger(RedisThrottlerStorage.name)
    private readonly logger: PinoLogger,
  ) {}

  onModuleInit(): void {
    // `defineCommand` fait parler EVALSHA au client, avec repli automatique
    // sur EVAL si Redis a oublié le script (redémarrage, SCRIPT FLUSH). Le
    // corps du script ne traverse donc le réseau qu'une fois.
    this.redis.getClient().defineCommand(COMMAND, { numberOfKeys: 2, lua: THROTTLE_LUA });
  }

  async increment(
    key: string,
    ttl: number,
    limit: number,
    blockDuration: number,
    throttlerName: string,
  ): Promise<VerdictDeDebit> {
    // `blockDuration` est déjà résolu à `ttl` par le guard quand il n'est pas
    // réglé ; la garde ci-dessous couvre l'appel direct depuis un test.
    const blockMs = blockDuration > 0 ? blockDuration : ttl;
    const namespace = `carlys:throttle:${throttlerName}:${key}`;

    try {
      const client = this.redis.getClient() as RedisWithThrottle;
      const [hits, msToExpire, blocked, msToBlockExpire] = await client[COMMAND](
        namespace,
        `${namespace}:bloc`,
        String(ttl),
        String(limit),
        String(blockMs),
      );
      return {
        totalHits: hits,
        // @nestjs/throttler publie ces deux durées en SECONDES dans
        // `Retry-After` et `X-RateLimit-Reset` ; le script raisonne en
        // millisecondes. `ceil` pour ne jamais annoncer une réouverture avant
        // l'heure.
        timeToExpire: Math.ceil(msToExpire / 1_000),
        isBlocked: blocked === 1,
        timeToBlockExpire: Math.ceil(msToBlockExpire / 1_000),
      };
    } catch (error) {
      this.warnOnce(error);
      return this.fallback.increment(key, ttl, limit, blockDuration, throttlerName);
    }
  }

  private warnOnce(error: unknown): void {
    const now = Date.now();
    if (now - this.lastWarnAt < WARN_INTERVAL_MS) {
      return;
    }
    this.lastWarnAt = now;
    this.logger.warn(
      { err: error },
      'Limitation de débit repliée en mémoire : Redis injoignable, le quota n’est plus partagé entre réplicas',
    );
  }
}
