import { Injectable, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { Redis } from 'ioredis';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../config/app-config.service';

/**
 * Client Redis partagé (cache, quotas, files BullMQ à venir).
 *
 * L'API démarre même si Redis est indisponible — la readiness le signale —
 * mais elle n'attend pas la première requête utilisateur pour se connecter.
 */
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly client: Redis;

  constructor(
    config: AppConfigService,
    @InjectPinoLogger(RedisService.name)
    private readonly logger: PinoLogger,
  ) {
    this.client = new Redis(config.redisUrl, {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      // Les commandes ATTENDENT la connexion au lieu d'être rejetées.
      //
      // Avec `false`, la toute première commande d'un processus échouait
      // systématiquement : ioredis lance la connexion puis, le flux n'étant
      // pas encore ouvert, rejette la commande qui vient de la déclencher.
      // Une commande sur des milliers, mais toujours la PREMIÈRE — donc le
      // premier message de coach après chaque redémarrage. `maxRetriesPerRequest`
      // garde le garde-fou qui comptait : un Redis réellement absent échoue
      // vite au lieu de faire attendre indéfiniment.
      enableOfflineQueue: true,
      retryStrategy: (times) => Math.min(times * 200, 2_000),
    });
    this.client.on('error', (error) => {
      this.logger.warn({ err: error }, 'Erreur de connexion Redis');
    });
  }

  /**
   * Ouvre la connexion au démarrage, sans faire échouer le démarrage : un
   * Redis absent doit se voir dans la readiness, pas empêcher l'API de
   * servir les routes qui n'en ont pas besoin. La stratégie de reconnexion
   * prend le relais en arrière-plan.
   */
  async onModuleInit(): Promise<void> {
    if (this.client.status !== 'wait') {
      return;
    }
    try {
      await this.client.connect();
    } catch (error) {
      this.logger.warn({ err: error }, 'Redis injoignable au démarrage');
    }
  }

  getClient(): Redis {
    return this.client;
  }

  async ping(): Promise<void> {
    if (this.client.status === 'wait' || this.client.status === 'end') {
      await this.client.connect();
    }
    await this.client.ping();
  }

  async onModuleDestroy(): Promise<void> {
    try {
      await this.client.quit();
    } catch {
      this.client.disconnect();
    }
  }
}
