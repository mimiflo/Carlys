import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { logFingerprint } from '../../../common/utilities/log-privacy';
import { AppConfigService } from '../../../config/app-config.service';
import { RedisService } from '../../../infrastructure/cache/redis.service';

export interface LockoutStatus {
  locked: boolean;
  /** Secondes restantes avant déverrouillage (si verrouillé). */
  retryAfterSeconds?: number;
}

/**
 * Message renvoyé quand le compte est verrouillé. Le même pour le mobile et
 * le back-office, et sans rien dire de l'état du compte : ni s'il existe,
 * ni pourquoi il est fermé.
 */
export function lockoutMessage(status: LockoutStatus): string {
  const minutes = Math.ceil((status.retryAfterSeconds ?? 60) / 60);
  return `Trop de tentatives. Réessaie dans ${minutes} minute(s).`;
}

/**
 * Limitation des tentatives de connexion : compteur Redis par identifiant
 * (e-mail normalisé, préfixé par l'appelant s'il veut son propre compteur)
 * avec verrouillage temporaire au-delà du seuil. Tout appelant suit le même
 * geste : [reserveAttempt] AVANT de vérifier le mot de passe, [reset] après
 * un succès (connexion mobile, connexion du back-office, ré-authentification).
 *
 * Si Redis est indisponible, le service laisse passer (fail-open) en le
 * journalisant : la disponibilité de la connexion prime, le rate limiting
 * HTTP global reste actif.
 */
@Injectable()
export class LockoutService {
  constructor(
    private readonly redis: RedisService,
    private readonly config: AppConfigService,
    @InjectPinoLogger(LockoutService.name)
    private readonly logger: PinoLogger,
  ) {}

  private key(identifier: string): string {
    return `auth:lockout:${identifier}`;
  }

  /**
   * RÉSERVE un essai, AVANT la vérification du mot de passe, et dit s'il
   * est permis. Un succès doit ensuite appeler [reset] ; un échec n'a plus
   * rien à compter.
   *
   * POURQUOI RÉSERVER PLUTÔT QUE LIRE PUIS COMPTER. Le service lisait le
   * compteur (`status`), laissait vérifier le mot de passe, puis comptait
   * l'échec (`recordFailure`) : des essais SIMULTANÉS lisaient tous le
   * compteur avant qu'aucun n'ait compté le sien, et tous faisaient vérifier
   * leur mot de passe. Mesuré avant correctif : 30 essais parallèles venus
   * de 30 adresses IP, 25 vérifiés au lieu de 5 sur `change-password`, 30
   * sur 30 à la connexion. `INCR` est atomique : parmi N essais simultanés,
   * exactement `maxLoginAttempts` reçoivent un rang permis. Les deux
   * anciennes méthodes sont retirées, pour qu'aucun appelant n'y revienne.
   *
   * Un essai REFUSÉ doit tomber en 429 AVANT toute lecture du compte et
   * toute vérification Argon2 : même juste, il ne dit rien.
   *
   * La fenêtre repart à chaque essai PERMIS, jamais à un essai refusé :
   * insister pendant le verrouillage ne le prolonge pas, sans quoi un
   * attaquant tiendrait le propriétaire dehors indéfiniment.
   */
  async reserveAttempt(identifier: string): Promise<LockoutStatus> {
    try {
      const client = this.redis.getClient();
      const key = this.key(identifier);
      const windowSeconds = this.config.lockoutMinutes * 60;
      const attempt = await client.incr(key);
      if (attempt <= this.config.maxLoginAttempts) {
        await client.expire(key, windowSeconds);
        return { locked: false };
      }
      if (attempt === this.config.maxLoginAttempts + 1) {
        this.logger.warn(
          { identifierHash: logFingerprint(identifier, this.config.logFingerprintKey) },
          'Verrouillage temporaire déclenché',
        );
      }
      const ttl = await client.ttl(key);
      if (ttl === -1) {
        // Clé sans échéance (écriture interrompue entre INCR et EXPIRE) :
        // on la borne ici, sinon le compte resterait fermé pour toujours.
        await client.expire(key, windowSeconds);
        return { locked: true, retryAfterSeconds: windowSeconds };
      }
      return { locked: true, retryAfterSeconds: ttl > 0 ? ttl : 1 };
    } catch (error) {
      this.logger.warn({ err: error }, 'Redis indisponible — verrouillage non appliqué');
      return { locked: false };
    }
  }

  async reset(identifier: string): Promise<void> {
    try {
      await this.redis.getClient().del(this.key(identifier));
    } catch (error) {
      this.logger.warn({ err: error }, 'Redis indisponible — compteur non réinitialisé');
    }
  }
}
