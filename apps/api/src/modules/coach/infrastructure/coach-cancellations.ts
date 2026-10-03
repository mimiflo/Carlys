import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { RedisService } from '../../../infrastructure/cache/redis.service';
import { turnKey } from '../application/coach.quota';

/** Le temps d'entendre « Arrêter » : un tour en cours s'arrête dans la seconde. */
const WATCH_EVERY_MS = 1_000;
/** Une demande d'arrêt qu'aucun tour n'a lue s'efface seule. */
const REQUEST_TTL_S = 15 * 60;

/**
 * « Arrêter », demandé EXPLICITEMENT — et seulement ainsi.
 *
 * Une connexion fermée (page quittée, appli fermée, réseau coupé) n'arrête
 * plus rien : le coach finit sa réponse et l'archive, et la personne la
 * retrouve au retour (ADR 0013, mise à jour du 3 octobre 2026). Arrêter
 * reste possible, par une demande posée dans Redis : le tour peut tourner
 * sur un AUTRE exemplaire de l'API que celui qui reçoit la demande, et
 * chacun la lit.
 */
@Injectable()
export class CoachCancellations {
  constructor(
    private readonly redis: RedisService,
    @InjectPinoLogger(CoachCancellations.name) private readonly logger: PinoLogger,
  ) {}

  private key(userId: string, messageId: string): string {
    return `coach:cancel:${userId}:${messageId}`;
  }

  /**
   * La personne arrête la réponse à SON message (la clé porte son identité).
   * Sans tour en cours, rien n'est posé : une demande d'avant le tour
   * (« Arrêter » sur un envoi jamais arrivé) n'arrêtera pas le renvoi de la
   * même question.
   */
  async request(userId: string, messageId: string): Promise<void> {
    const client = this.redis.getClient();
    if ((await client.exists(turnKey(messageId))) === 0) return;
    await client.set(this.key(userId, messageId), '1', 'EX', REQUEST_TTL_S);
  }

  /**
   * Le signal d'un tour : il s'abat sur une demande d'arrêt, ou sur [outer]
   * (un appelant interne). `dispose` cesse de guetter et efface la demande,
   * pour qu'un renvoi plus tard de la même question ne s'arrête pas d'office.
   */
  watch(
    userId: string,
    messageId: string,
    outer?: AbortSignal,
  ): { signal: AbortSignal; dispose: () => Promise<void> } {
    const controller = new AbortController();
    const abort = () => controller.abort();
    outer?.addEventListener('abort', abort, { once: true });
    const key = this.key(userId, messageId);
    const timer = setInterval(() => {
      this.redis
        .getClient()
        .exists(key)
        .then((found) => {
          if (found === 1) abort();
        })
        .catch((error: unknown) =>
          // Redis absent un instant : la réponse continue, l'arrêt sera lu
          // au battement suivant.
          this.logger.warn({ err: error, messageId }, 'Demande d’arrêt illisible'),
        );
    }, WATCH_EVERY_MS);
    timer.unref();
    return {
      signal: controller.signal,
      dispose: async () => {
        clearInterval(timer);
        outer?.removeEventListener('abort', abort);
        await this.redis
          .getClient()
          .del(key)
          .catch((error: unknown) =>
            this.logger.warn({ err: error, messageId }, 'Demande d’arrêt non effacée'),
          );
      },
    };
  }
}
