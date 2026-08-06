import { Injectable, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../config/app-config.service';

/**
 * Unique point d'accès Prisma. Les contrôleurs ne l'utilisent jamais
 * directement : seuls les repositories/services de domaine y accèdent.
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor(
    config: AppConfigService,
    @InjectPinoLogger(PrismaService.name)
    private readonly logger: PinoLogger,
  ) {
    super({ datasourceUrl: config.databaseUrl });
  }

  async onModuleInit(): Promise<void> {
    try {
      await this.$connect();
      this.logger.info('Connexion PostgreSQL établie');
    } catch (error) {
      // L'application démarre quand même : /health/ready signalera la panne
      // et Prisma retentera la connexion à la prochaine requête.
      this.logger.error(
        { err: error },
        'Connexion PostgreSQL impossible au démarrage — readiness dégradée',
      );
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
