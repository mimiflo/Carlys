import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
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
 * avec verrouillage temporaire au-delà du seuil.
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

  async status(identifier: string): Promise<LockoutStatus> {
    try {
      const client = this.redis.getClient();
      const attempts = await client.get(this.key(identifier));
      if (attempts === null || Number(attempts) < this.config.maxLoginAttempts) {
        return { locked: false };
      }
      const ttl = await client.ttl(this.key(identifier));
      return { locked: true, retryAfterSeconds: ttl > 0 ? ttl : 1 };
    } catch (error) {
      this.logger.warn({ err: error }, 'Redis indisponible — verrouillage non appliqué');
      return { locked: false };
    }
  }

  async recordFailure(identifier: string): Promise<void> {
    try {
      const client = this.redis.getClient();
      const attempts = await client.incr(this.key(identifier));
      // La fenêtre repart à chaque échec : un attaquant ne « déverrouille »
      // pas le compte en insistant.
      await client.expire(this.key(identifier), this.config.lockoutMinutes * 60);
      if (attempts === this.config.maxLoginAttempts) {
        this.logger.warn({ identifier }, 'Verrouillage temporaire déclenché');
      }
    } catch (error) {
      this.logger.warn({ err: error }, 'Redis indisponible — échec non comptabilisé');
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
